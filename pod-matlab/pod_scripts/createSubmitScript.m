function createSubmitScript(outputFilename, jobName, quotedLogFile, quotedScriptName, ...
    environmentVariables, props)
% Create a script that sets the correct environment variables and then 
% executes the PBS qsub command.

% Copyright 2010-2012 The MathWorks, Inc.

% Open file in binary mode to make it cross-platform.
fid = fopen(outputFilename, 'w');
if fid < 0
    error('parallelexamples:GenericPBS:FileError', ... 
        'Failed to open file %s for writing', outputFilename);
end

% Specify Shell to use
fprintf(fid, '#!/bin/sh\n');

% Write the commands to set and export environment variables
for ii = 1:size(environmentVariables, 1)
    fprintf(fid, '%s=%s\n', environmentVariables{ii,1}, environmentVariables{ii,2});
    fprintf(fid, 'export %s\n', environmentVariables{ii,1});
end

% Generate the command to run and write it.
% We will forward all environment variables with this job in the call
% to qsub
variablesToForward = environmentVariables(:,1);
commandToRun = getSubmitString(jobName, quotedLogFile, quotedScriptName, ...
    variablesToForward, props);   
fprintf(fid, '%s\n', commandToRun);

% Close the file
fclose(fid);

