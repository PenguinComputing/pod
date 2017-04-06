function asa = getAdditionalSubmitArguments(props)

asa = '';
currFilename = mfilename;

% Query for PPN or set Default 1
ppn = ClusterInfo.getProcsPerNode();
if isempty(ppn)==true
    ppn = 1;
end

%% REQUIRED


%% OPTIONAL

% Query for the Walltime
wt = ClusterInfo.getWallTime();
if isempty(wt)==false
    asa = [asa ' -l walltime=' wt];
end

% Query for the queue name
qn = ClusterInfo.getQueueName();
if isempty(qn)==false
    asa = [asa ' -q ' qn];
end

% Check if user wants email updates
ea = ClusterInfo.getEmailAddress();
if isempty(ea)==false
    % User wants to be emailed the job status
    asa = [asa ' -M ' ea ' -m abe'];
end

ppn = min(props.NumberOfTasks,ppn);
numberOfNodes = ceil(props.NumberOfTasks/ppn);

asa = [asa sprintf(' -l nodes=%d:ppn=%d', numberOfNodes, ppn)];
dctSchedulerMessage(4, '%s: Requesting %d nodes with %d processors per node', currFilename, ...
    numberOfNodes, ppn);

%{
% TODO
% Every job is going to require a certain number of MDCS licenses.
% However, this MDCS installation is going to use MHLM, so we're
% not going to request MDCS licenses as a resource.
%}

udo = ClusterInfo.getUserDefinedOptions();
if isempty(udo)==false
    asa = [asa ' ' udo];
end

asa = strtrim(asa);
