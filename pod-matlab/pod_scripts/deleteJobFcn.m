function deleteJobFcn(cluster, job)
%DELETEJOBFCN Deletes a job on PBS
%
% Set your cluster's DeleteJobFcn to this function using the following
% command:
%     set(cluster, 'DeleteJobFcn', @deleteJobFcn);

% Copyright 2010-2012 The MathWorks, Inc.

% Store the current filename for the errors, warnings and dctSchedulerMessages
currFilename = mfilename;
if ~isa(cluster, 'parallel.Cluster')
    error('parallelexamples:GenericPBS:SubmitFcnError', ...
        'The function %s is for use with clusters created using the parcluster command.', currFilename)
end
if cluster.HasSharedFilesystem
    error('parallelexamples:GenericPBS:SubmitFcnError', ...
        'The submit function %s is for use with nonshared filesystems.', currFilename)
end
 % Get the information about the actual cluster used
data = cluster.getJobClusterData(job);
if isempty(data)
    % This indicates that the job has not been submitted, so just return
    dctSchedulerMessage(1, '%s: Job cluster data was empty for job with ID %d.', currFilename, job.ID);
    return
end
try
    clusterHost = data.RemoteHost;
    remoteJobStorageLocation = data.RemoteJobStorageLocation;
catch err
    ex = MException('parallelexamples:GenericPBS:FailedToRetrieveRemoteParameters', ...
        'Failed to retrieve remote parameters from the job cluster data.');
    ex = ex.addCause(err);
    throw(ex);
end
remoteConnection = getRemoteConnection(cluster, clusterHost, remoteJobStorageLocation);
try
    jobIDs = data.ClusterJobIDs;
catch err
    ex = MException('parallelexamples:GenericPBS:FailedToRetrieveJobID', ...
        'Failed to retrieve clusters''s job IDs from the job cluster data.');
    ex = ex.addCause(err);
    throw(ex);
end

% Only ask the cluster to delete the job if it is hasn't reached a terminal
% state.  
erroredJobs = cell(size(jobIDs));
jobState = job.State;
if ~(strcmp(jobState, 'finished') || strcmp(jobState, 'failed'))
    % Get the cluster to delete the job
    for ii = 1:length(jobIDs)
        jobID = jobIDs{ii};
        commandToRun = sprintf('qdel "%s"', jobID);
        dctSchedulerMessage(4, '%s: Deleting job on cluster using command:\n\t%s.', currFilename, commandToRun);
        % Keep track of all jobs that were not deleted successfully - either through
        % a bad exit code or if an error was thrown.  We'll report these later on.
        try
            % Execute the command on the remote host.
            [cmdFailed, cmdOut] = remoteConnection.runCommand(commandToRun);
        catch err
            cmdFailed = true;
            cmdOut = err.message;
        end
        if cmdFailed
            erroredJobs{ii} = jobID;
            dctSchedulerMessage(1, '%s: Failed to delete job %d on cluster.  Reason:\n\t%s', currFilename, jobID, cmdOut);
        end
    end
end

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
% Now warn about those jobs that we failed to delete.
erroredJobs = erroredJobs(~cellfun(@isempty, erroredJobs));
if ~isempty(erroredJobs)
    warning('parallelexamples:GenericPBS:FailedToDeleteJob', ...
        'Failed to delete the following jobs on the cluster:\n%s', ...
        sprintf('\t%s\n', erroredJobs{:}));
end
