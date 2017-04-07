function [job, pjob, sjob, b] = testCluster(action,nlabs)

job = []; pjob = []; sjob = []; b = [];
if nargin==0, action=6; nlabs=4; end

c = parcluster();

% Task-Parallel
if action==1 || action==6
    try
        job = c.createJob();
        for tidx = 1:nlabs
            %             job.createTask(@system,2,{'hostname'});
            %             job.createTask(@pause,0,{3*60});
            job.createTask(@rand,1,{});
        end
        job.submit
    catch ME
        disp(ME.message)
    end
end

% MATLAB Pool (i.e. batch)
if action==2 || action==6
    try
        pjob = c.createCommunicatingJob('Type','pool','NumWorkersRange',nlabs);
        %         pjob.createTask(@system,2,{'hostname'});
        %         pjob.createTask(@pause,0,{5 * 60});
        % pjob.createTask(@rand,1,{});
                 pjob.createTask(@labindex,1,{});
        pjob.submit
    catch ME
        disp(ME.message)
    end
end

% Data-Parallel
if action==3 || action==6
    try
        sjob = c.createCommunicatingJob('Type','spmd','NumWorkersRange',nlabs);
        %         sjob.createTask(@system,2,{'hostname'});
                 sjob.createTask(@pause,0,{5 * 60});
        %sjob.createTask(@rand,1,{});
        %         sjob.createTask(@labindex,1,{});
        sjob.submit
    catch ME
        disp(ME.message)
    end

end

% Interative MATLAB Pool
if action==4 || action==60
    try
        if matlabpool('size')>0, matlabpool close, end
        matlabpool
        parfor idx = 1:nlabs
            %             [r, s] = system('hostname')
            %             pause(60)
            disp('Calculating r value...')
            r = rand();
            disp(['r value is ' num2str(r)])
        end
        matlabpool close
    catch ME
        disp(ME.message)
    end
end

% Batch
if action==5 || action==6
    try
        %         fcn = @system; N = 2; ip = {};
        %         fcn = @pause; N = 0; ip = {60};
        fcn = @rand; N = 1; ip = {};
        %         fcn = @labindex; N = 1; ip = {};
        b = batch(fcn,N,ip,'CaptureDiary',true,'Matlabpool',nlabs-1);
    catch ME
        disp(ME.message)
    end
end
