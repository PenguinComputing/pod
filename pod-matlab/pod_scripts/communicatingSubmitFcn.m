function communicatingSubmitFcn(cluster, job, props, ...
    clusterHost, remoteJobStorageLocation)
%COMMUNICATINGSUBMITFCN Submit a communicating MATLAB job to a PBS cluster
%
% Set your cluster's CommunicatingSubmitFcn to this function using the following
% command:
%     set(cluster, 'CommunicatingSubmitFcn', {@communicatingSubmitFcn, clusterHost, remoteJobStorageLocation});
%
% See also parallel.cluster.generic.communicatingDecodeFcn.
%

% Copyright 2010-2012 The MathWorks, Inc.

if strcmp(job.Tag,'Created_by_matlabpool') || strcmp(job.Tag,'Created_by_parpool')
   CR = 10;
   TAB = 9;
   emsg = [CR CR '****************************************************' ...
        CR cluster.Profile ' does not support calling' ...
        CR CR TAB '>> matlabpool open ' cluster.Profile ' ' num2str(numel(job.Tasks)) ...
        CR CR 'Instead, use batch()' ...
        CR CR TAB '>> job = batch(...);' ...
        CR CR 'Call' ...
        CR CR TAB '>> doc batch' ...
        CR CR 'for more help.' ...
        CR '****************************************************' ...
        ];
    disp(emsg)
    error(emsg)
end

% Store the current filename for the errors, warnings and dctSchedulerMessages
currFilename = mfilename;
if ~isa(cluster, 'parallel.Cluster')
    error('parallelexamples:GenericPBS:SubmitFcnError', ...
        'The function %s is for use with clusters created using the parcluster command.', currFilename)
end

decodeFunction = 'parallel.cluster.generic.communicatingDecodeFcn';

if cluster.HasSharedFilesystem
    error('parallelexamples:GenericPBS:SubmitFcnError', ...
        'The submit function %s is for use with nonshared filesystems.', currFilename)
end

if ~strcmpi(cluster.OperatingSystem, 'unix')
    error('parallelexamples:GenericPBS:SubmitFcnError', ...
        'The submit function %s only supports clusters with unix OS.', currFilename)
end
if ~ischar(clusterHost)
    error('parallelexamples:GenericPBS:IncorrectArguments', ...
        'Hostname must be a string');
end
if ~ischar(remoteJobStorageLocation)
    error('parallelexamples:GenericPBS:IncorrectArguments', ...
        'Remote job storage location must be a string');
end

remoteConnection = getRemoteConnection(cluster, clusterHost, remoteJobStorageLocation);

% The job specific environment variables
% Remove leading and trailing whitespace from the MATLAB arguments
matlabArguments = strtrim(props.MatlabArguments);
variables = {'MDCE_DECODE_FUNCTION', decodeFunction; ...
    'MDCE_STORAGE_CONSTRUCTOR', props.StorageConstructor; ...
    'MDCE_JOB_LOCATION', props.JobLocation; ...
    'MDCE_MATLAB_EXE', props.MatlabExecutable; ... 
    'MDCE_MATLAB_ARGS', matlabArguments; ...
    'MDCE_DEBUG', 'true'; ...
    'MLM_WEB_LICENSE', props.UseMathworksHostedLicensing; ...
    'MLM_WEB_USER_CRED', props.UserToken; ...
    'MLM_WEB_ID', props.LicenseWebID; ...
    'MDCE_LICENSE_NUMBER', props.LicenseNumber; ...
    'MDCE_STORAGE_LOCATION', remoteJobStorageLocation; ...
    'MDCE_CMR', cluster.ClusterMatlabRoot; ...
    'MDCE_TOTAL_TASKS', num2str(props.NumberOfTasks); ...
    'MDCE_TOTAL_TASKS_OTHER', num2str(props.NumberOfTasks); ...
    };

% Get the correct quote and file separator for the Cluster OS.  
% This check is unnecessary in this file because we explicitly 
% checked that the ClusterOsType is unix.  This code is an example 
% of how your integration code should deal with clusters that 
% can be unix or pc.
if strcmpi(cluster.OperatingSystem, 'unix')
    quote = '''';
    fileSeparator = '/';
else 
    quote = '"';
    fileSeparator = '\';
end

% The local job directory
localJobDirectory = cluster.getJobFolder(job);
% How we refer to the job directory on the cluster
remoteJobDirectory = remoteConnection.getRemoteJobLocation(job.ID, cluster.OperatingSystem);

% The script name is communicatingJobWrapper.sh
scriptName = 'communicatingJobWrapper.sh';
% The wrapper script is in the same directory as this file
dirpart = fileparts(mfilename('fullpath'));
localScript = fullfile(dirpart, scriptName);
% Copy the local wrapper script to the job directory
copyfile(localScript, localJobDirectory);

% The command that will be executed on the remote host to run the job.
remoteScriptName = sprintf('%s%s%s', remoteJobDirectory, fileSeparator, scriptName);
quotedScriptName = sprintf('%s%s%s', quote, remoteScriptName, quote);

% Choose a file for the output. Please note that currently, JobStorageLocation refers
% to a directory on disk, but this may change in the future.
logFile = sprintf('%s%s%s', remoteJobDirectory, fileSeparator, sprintf('Job%d.log', job.ID));
quotedLogFile = sprintf('%s%s%s', quote, logFile, quote);

jobName = sprintf('Job%d', job.ID);
% PBS jobs names must not exceed 15 characters
maxJobNameLength = 15;
if length(jobName) > maxJobNameLength
    jobName = jobName(1:maxJobNameLength);
end
% This is handled by getAdditionalSubmitArguments()
%procsPerNode = 16;
%numberOfNodes = ceil(props.NumberOfTasks/procsPerNode);
%dctSchedulerMessage(4, '%s: Requesting %d nodes with %d processors per node', currFilename, ...
%    numberOfNodes, procsPerNode);

% Create a script to submit a PBS job - this will be created in the job directory
dctSchedulerMessage(5, '%s: Generating script for job.', currFilename);
localScriptName = tempname(localJobDirectory);
[~, scriptName] = fileparts(localScriptName);
remoteScriptLocation = sprintf('%s%s%s', remoteJobDirectory, fileSeparator, scriptName);
createSubmitScript(localScriptName, jobName, quotedLogFile, quotedScriptName, ...
    variables, props);
% Create the command to run on the remote host.
commandToRun = sprintf('sh %s', remoteScriptLocation);
dctSchedulerMessage(4, '%s: Starting mirror for job %d.', currFilename, job.ID);
% Start the mirror to copy all the job files over to the cluster
remoteConnection.startMirrorForJob(job);

% Now ask the cluster to run the submission command
dctSchedulerMessage(4, '%s: Submitting job using command:\n\t%s', currFilename, commandToRun);
% Execute the command on the remote host.
[cmdFailed, cmdOut] = remoteConnection.runCommand(commandToRun);
if cmdFailed
    % Stop the mirroring if we failed to submit the job - this will also
    % remove the job files from the remote location
    % Only stop mirroring if we are actually mirroring
    if remoteConnection.isJobUsingConnection(job.ID)
        dctSchedulerMessage(5, '%s: Stopping the mirror for job %d.', currFilename, job.ID);
        try
            remoteConnection.stopMirrorForJob(job);
        catch err
            warning('parallelexamples:GenericPBS:FailedToStopMirrorForJob', ...
                'Failed to stop the file mirroring for job %d.\nReason: %s', ...
                job.ID, err.getReport);
        end
    end
    error('parallelexamples:GenericPBS:FailedToSubmitJob', ...
        'Failed to submit job to PBS using command:\n\t%s.\nReason: %s', ...
        commandToRun, cmdOut);
end

jobIDs = extractJobId(cmdOut);
% jobIDs must be a cell array
if isempty(jobIDs)
    warning('parallelexamples:GenericPBS:FailedToParseSubmissionOutput', ...
        'Failed to parse the job identifier from the submission output: "%s"', ...
        cmdOut);
end
if ~iscell(jobIDs)
    jobIDs = {jobIDs};
end

% set the cluster host, remote job storage location and job ID on the job cluster data
jobData = struct('ClusterJobIDs', {jobIDs}, ...
    'RemoteHost', clusterHost, ...
    'RemoteJobStorageLocation', remoteJobStorageLocation, ...
    'HasDoneLastMirror', false);
cluster.setJobClusterData(job, jobData);


