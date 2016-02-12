# lsyncd-acd-conf

An Amazon Cloud Drive lsync configuration that supports live-sync and encryption

### Dependencies

- lsyncd
- zenity
- encfs
- acd_cli

### Configuration

### ***acd_path***
1. Setup your acd_cli http://acd-cli.readthedocs.org/en/latest/setup.html
2. Authorize your computer to connect to your acd: http://acd-cli.readthedocs.org/en/latest/authorization.html
3. Ensure acd_cli mount works: `acd_cli mount /path/to/acdRemoteMount`. This path is `acd_path`

You can use the acd remote mount unencrypted and encrypt a subfolder. This is the top level folder which will contain the entire acd mount.

### ***source***
1. Make an empty local folder where you will store/access/use your files, e.g. `/path/to/local/folder`. This path is `source`

### ***acd_encfs_conf***
1. Make a file in the empty local folder, e.g. `/path/to/local/folder/ThisIsMyAcdEncryptedRoot.txt`
2. Setup encryption (encfs) on the folder and mount it anywhere, e.g. `/path/to/local/encryptedFolder`
3. Move the .encfs6.xml file somewhere else (not on acd, not in the local folder) and backup the file somewhere else. .e.g. `/path/to/local/.encfs6.xml` This file is `acd_encfs_conf`

### ***acd_encfs_src***
1. Copy the local/encryptedFolder to your acd, e.g. `cp /path/to/local/encryptedFolder /path/to/acdRemoteMount/encryptedFolder`. This path `acd_encfs_src`.

### ***target***
1. Your `acd_encfs_src` `/path/to/acdRemoteMount/encryptedFolder` should have had one file with a random looking name, about the same size as your txt file above.
2. Unmount the local/encryptedFolder mount, e.g. `/path/to/local/encryptedFolder`
3. Make a mount path for the decrypted mount of that remote folder, e.g. `/path/to/acdRemoteFolderDecryptedMount`. This path is `target`

# Testing

Ensure the decrypted mount contains your text file. Replace the "config.*" variables in the command below to test: `ENCFS6_CONFIG=config.acd_encfs_conf encfs config.acd_encfs_src config.target`

e.g. `ENCFS6_CONFIG=/path/to/local/.encfs6.xml encfs /path/to/acdRemoteMount/encryptedFolder /path/to/acdRemoteFolderDecryptedMount`


You can unmount them both now. First the encfs, then the acd. Then you can run this lsyncd to boot them back up and sync.

Once it's running, you can drop files into your local/folder and they'll be encrypted and pushed to acd.

# Alternatives
You could also setup local > localencfs (--reverse) > acd, but localencfs does not fire inotify to lsyncd.
A more complex lsyncd that watches local, but does cp/mv/rm from localencfs to acd/encrypted_folder may also work

# Contributors

Thanks goes out to https://amc.ovh/2015/08/14/mounting-uploading-amazon-cloud-drive-encrypted.html
