%pod_cluster_ip = getenv('POD_CLUSTER_IP');
%pod_client_location = getenv('POD_CLIENT_LOCATION');
%pod_remote_location = getenv('POD_REMOTE_LOCATION');

cluster = 'POD';
% The location of MATLAB as compared to the cluster
type = 'remote';

% The version of MATLAB being supported
release = ['R' version('-release')];

pod_base_profile = 'POD.settings';

% POD IP Addres
pod_cluster_ip = '';

% User Name
pod_user = '';
pod_license_number = 'foobar';
pod_uses_mhlm = 0;
range_check = @(x) x < 58 & x > 46;

%TODO:DONE - get necessary values:

if isempty(javachk('awt'))
    % MATLAB has been started with a desktop, so use dialogs to get credential data.
    prompt = {'IP Address of Login Node:','POD System Account:','Use Mathworks Hosted License? (Y/N)','Mathworks License Number'};
    title = 'POD REmote Cluster Setup';
    num_lines = 1;
    default = {'','','Y',''};
    out = inputdlg(prompt,title,num_lines,default);
    pod_cluster_ip = out{1};
    if isempty(pod_cluster_ip)
        error('Must provide the IP address of your Login Node');
    end
    pod_user = out{2};
    if isempty(pod_user)
        error('Must provide your user name on POD');
    end
    pod_uses_mhlm = out{3};
    pod_uses_mhlm = pod_uses_mhlm(1)=='Y';
    pod_license_number = out{4};
else
    % MATLAB has been started in nodisplay mode, so use command line to get credential data
    pod_cluster_ip = input('Enter the IP address of your POD Login Node:    ', 's');
    if isempty(pod_cluster_ip)
        error('Must provide the IP address of your Login Node')
    end

    pod_user = input('Enter your POD user name:    ', 's');
    if isempty(pod_user)
        error('Must provide your user name on POD')
    end

    pod_uses_mhlm = upper(input('Are you using Mathworks Hosted License Management? [y/N]    ', 's'));
    pod_uses_mhlm = pod_uses_mhlm(1)=='Y';
    %range check just makes sure the given string represents a license number
    while pod_uses_mhlm && ~ all(range_check(pod_license_number))
        pod_license_number = input('Enter your MHLM license number:    ', 's');
    end
end

% Remote Storage Location
rjsl = ['/home/' pod_user '/MdcsDataLocation/' cluster '/' release '/' type];

% Local Storage Location 
jfolder = fullfile(tempdir,'MdcsDataLocation',cluster,release,type);
if exist(jfolder,'dir')==false
    [status,err,eid] = mkdir(jfolder);
    if status==false
        error(eid,err)
    end
end

% The location of the cluster profile
pfolder = fileparts(mfilename('fullpath'));
pfiles = dir(fullfile(pfolder, '*.settings'));
len = length(pfiles);
if len==0
   error(['Failed to find the ' cluster ' profile.  Contact the Administrator.'])
elseif len>1
   error(['Found potentially more than one profile for ' cluster '.  Contact the Administrator.'])
end

profile = strtok(pfiles.name,'.');
profile_loc = fullfile(pfolder,pfiles.name);

% Delete the old profile (if it exists)
profiles = parallel.clusterProfiles();
idx = strcmp(profiles,profile);
ps = parallel.Settings;
ws = warning;
warning off %#ok<WNOFF>
ps.Profiles(idx).delete
warning(ws)

% Import the profile
p = parallel.importProfile(profile_loc);

% Get a handle to the profile
c = parcluster(p);
c.JobStorageLocation = jfolder;
c.IndependentSubmitFcn{2} = pod_cluster_ip;
c.CommunicatingSubmitFcn{2} = pod_cluster_ip;
c.IndependentSubmitFcn{3} = rjsl;
c.CommunicatingSubmitFcn{3} = rjsl;
c.LicenseNumber = pod_license_number;
c.RequiresMathWorksHostedLicensing = pod_uses_mhlm;
c.saveProfile

% Set as default profile
parallel.defaultClusterProfile(p);

fprintf(1, 'Adding POD scripts to MATLAB PATH...');
wd = pwd();
addpath(genpath(wd));
savepath();

% Connection Preferences
ClusterInfo.setClusterHost(pod_cluster_ip);
ClusterInfo.setUserNameOnCluster(pod_user);
ClusterInfo.setQueueName('H30');
ClusterInfo.setProcsPerNode(16);
ClusterInfo.setUseGpu(false);

% Set Connection Credentials
% if isempty(javachk('awt'))
%     % MATLAB has been started with a desktop, so use dialogs to get credential data.
%     [~, ~, ~, ~] = iGetCredentialsFromUI(pod_cluster_ip);
% else
%     % MATLAB has been started in nodisplay mode, so use command line to get credential data
%     [~, ~, ~, ~] = iGetCredentialsFromCommandLine(pod_cluster_ip);
% end

fprintf(1, ' Done.\nExiting.\n');

exit(0);

