%MarkovChain - class for first-order discrete Markov chain,%representing discrete random sequence of integer "state" numbers.%%A Markov state sequence S(t), t=1..T%is determined by fixed initial probabilities P[S(1)=j], and%fixed transition probabilities P[S(t) | S(t-1)]%%A Markov chain with FINITE duration has a special END state,%coded as nStates+1.%The sequence generation stops at S(T), if S(T+1)=(nStates+1)%%References:%Leijon, A. (20xx) Pattern Recognition. KTH, Stockholm.%%Arne Leijon,   2010-08-25, tested%               2011-07-31, minor fix to facilitate sub-class implementationclassdef MarkovChain < ProbGenModel%     properties (Dependent=true)%         nStates;% number of states (=size(TransitionProb,1))%         2011-07-31 instead defined by public method, to allow sub-class to change it%         %New cosmetic properties???:%         %*** FiniteDuration;???%         %*** Stationary;%property???%         %*** Ergodic;%property???%         %**** Check backward compatibility first *****%     end    properties (Access=public)        InitialProb=1;% column vector with initial probabilities:        %           InitialProb(i)= P[S(1) = i]        %           size(InitialProb)=[nStates 1]        TransitionProb=1;%  matrix with transition probabilities:        %           TransitionProb(i,j)= P[S(t)=j | S(t-1)=i]        %           If sequence duration is INFINITE,        %           size(TransitionProb)=[nStates, nStates].        %           If sequence duration is FINITE,        %                   size(TransitionProb)=[nStates, nStates+1]    end    methods (Access=public)        %--------------------------------Construction and Initialization methods:        function mc=MarkovChain(varargin)            %Constructor of a single MarkovChain object            %Usage:            %mc=MarkovChain; %creates a trivial MarkovChain with only one state            %mc=MarkovChain(mcIn);%just copies the given input object            %mc=MarkovChain(pInit,pTrans);%creates, with given InitialProb,TransitionProb            %for backward compatibility:            %mc=MarkovChain(propertyName,propertyValue,...)            %            %A square TransitionProb matrix defines a MarkovChain with INFINITE duration.            %If size(TransitionProb,2)=size(TransitionProb,1)+1,             %       the MarkovChain can have FINITE duration,            %and S(t)=nStates+1 is then the END state.            %            %Result:            %mc= constructed MarkovChain object            %            switch nargin                case 0%do nothing special, just default init                case 1                    if isa(varargin{1},'MarkovChain')                        mc=varargin{1};%just copy it                    else                        error(' Not a MarkovChain object');                    end                otherwise% 2 or more arguments                    if ischar(varargin{1})%allowed only for backward combatibility                        mc=setNamedProperties(mc,varargin{:});                    else                        mc.InitialProb=varargin{1};%in this order                        mc.TransitionProb=varargin{2};                    end            end        end        function nS=nStates(mc)            %number of interla states, 2011-07-31            nS=size(mc.TransitionProb,1);        end        function nS=nExtStates(mc)            %externally visible number of states,            %to allow sub-class to have different internal and external state structure.            %Arne Leijon, 2011-08-03            nS=mc.nStates;%default unless changed by subclass         end        function LR=isLeftRight(mc)            %test if the Markov chain has left-right transtion probability structure            LowLeft=tril(mc.TransitionProb,-1);%everything below/left of main diagonal            LR=all(LowLeft(:)==0);        end        function pD=probDuration(mc,tMax)            %pD=probDuration(mc,tMax)            %=probability mass of durations t=1...tMax, for a Markov Chain.            %Meaningful result only for finite-duration Markov Chain,            %as pD(:)== 0 for infinite-duration Markov Chain.            %Ref: Arne Leijon (201x) Pattern Recognition, KTH-SIP, Problem 4.8.            pInit=mc.InitialProb;            Q=mc.TransitionProb;            nS=size(Q,1);            Q=Q(:,1:nS)';            pD=zeros(1,tMax);%always zero for infinite-duration MarkovChain            if finiteDuration(mc)                pSt=(eye(size(Q))-Q)*pInit;%pSt(j)=P(S_t=j & S_{t+1}= END)                for t=1:tMax                    pD(t)=sum(pSt);%=P(D=t)                    pSt=Q*pSt;                end            end        end        function pD=probStateDuration(mc,tMax)            %=probability mass of state durations P[D=t], for t=1...tMax            %Ref: Arne Leijon (201x) Pattern Recognition, KTH-SIP, Problem 4.7.            t=1:tMax;            aii=diag(mc.TransitionProb);%column vector            logpD=bsxfun(@plus,log(aii)*(t-1),log(1-aii));            pD=exp(logpD);        end        function d=meanStateDuration(mc)            %expected value of number of time samples spent in each state            %Ref: Arne Leijon (201x) Pattern Recognition, KTH-SIP, Problem 4.7.            d=1./(1-diag(mc.TransitionProb));        end        %----------------------------   Signatures of separately defined methods:        %----- Initialization methods:        mc=initLeftRight(mc,nStates,stateDuration);%    initialize to finite-duration left-right structure.        mc=initErgodic(mc,nStates,stateDuration);%      initialize to infinite-duration stationary ergodic structure.        mc=setStationary(mc);%  set property InitialProb equal to a stationary state distribution.        %        %----- General Usage Methods:        fD=finiteDuration(mc);%         TRUE if the Markov chain has an END state and gives finite sequences        pState=stationaryProb(mc);%     calc stationary state probability        r=stateEntropyRate(mc);%        calc entropy rate (bits/transition) for state sequence        S=rand(mc,T);%                  generate random state sequence        lP=logprob(mc,S);%              log probability of observed state sequence        mc1=join(mc,pInit,pTrans);%     connect array of MarkovChain objects into a single MarkovChain        %        %----- Methods for use when the MarkovChain is part of a hidden Markov model:        [alfaHat, c]=forward(mc,pX);%   forward algorithm, used for HMM training        betaHat=backward(mc,pX,c);%     backward algorithm, used for HMM training        [optS,logP]=viterbi(mc,logpX);%    viterbi algorithm, find optimal state sequence        function [gamma,c]=forwardBackward(mc,pX)%combined forward-backward            %calculates state and observation probabilities for one single data sequence,            %using both forward and backward algorithms, for a given single MarkovChain object,            %            %Input:            %mc= single MarkovChain object            %pX= matrix with state-conditional likelihood values,            %   without considering the Markov depencence between sequence samples.            %	pX(j,t)= P( X(t)= observed x(t) | S(t)= j ); j=1..N; t=1..T            %	(must be pre-calculated externally)            %NOTE: pX may be arbitrarily scaled, as defined externally,            %   i.e. it may not be a properly normalized probability density or mass.            %Result:            %gamma=matrix with normalized state probabilities, given all observations:            %	gamma(j,t)=P[S(t)=j|x(1)...x(t)...x(T), HMM]; t=1..T            %c=row vector with observation probabilities, given the HMM:            %	c(t)=P[x(t) | x(1)...x(t-1),HMM]; t=1..T            %	c(1)*c(2)*..c(t)=P[x(1)..x(t)| HMM]            % Get the scaled forward and backward variables            T=size(pX,2);            [alfaHat c] = forward(mc,pX);            betaHat = backward(mc,pX,c);            % Calculate gamma            gamma = alfaHat.*betaHat.*repmat(c(1:T),mc.nStates,1);        end        %        %----- Low-level Training Methods for a single MarkovChain object:        aS=adaptStart(mc);        %           initialize accumulator data structure for training        [aState,gamma,lP]=adaptAccum(mc,aState,pX);        %           collect sufficient statistics from a single training sequence,        %           without changing the object itself        %           (to be called repeatedly with each available training sequence).        mc=adaptSet(mc,aState);%        finally adjust the object using accumulated statistics.        %        %           Results from adaptAccum must be stored externally,        %           if training is to be continued with several data sequences:        %           Usage:        %           a=adaptStart(mc);%create temp storage for statistics accumulator        %           for n=1:nTrainingSequences        %              a=adaptAccum(mc,a,getTrainingSequence(n));        %           end;        %           mc=adaptSet(mc,a);%new adapted object        %    end    %---------------------------------------------------------------    methods%get/set        function mc=set.InitialProb(mc,pInit)%with shape check and normalization            if isvector(pInit)                pInit=pInit(:);%should be a column vector                mc.InitialProb=pInit/sum(pInit);%normalize sum            else                error('InitialProb must be a vector');            end        end        function mc=set.TransitionProb(mc,pTrans)%with size check, and normalization            nS=length(mc.InitialProb);            nT=size(pTrans);            if nS~=nT(1) || nT(2)<nS || nS+1<nT(2)                warning('Incompatible TransitionProb size');            end            mc.TransitionProb=pTrans./repmat(sum(pTrans,2),1,nT(2));%normalize        end    end    %    methods (Access=private)        function mc=setNamedProperties(mc,varargin)%for backward compatibility            %set named property value            %varargin may include several (propName,value) pairs            property_argin = varargin;            while length(property_argin) >= 2                propName = property_argin{1};                v = property_argin{2};                property_argin = property_argin(3:end);                switch propName                    case {'InitialProb','initialprob'}                        mc.InitialProb=v;                    case {'TransitionProb','transitionprob'}                        mc.TransitionProb=v;                    otherwise                        error(['Cannot set property ',propName,' of MarkovChain object']);                end            end        end    endend