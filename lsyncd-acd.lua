settings {
    logfile = "/run/shm/lsyncd.log",
    statusFile = "/run/shm/lsyncd.status",
    statusInterval = 5,
    nodaemon = true,
}

acd = {
    -- rsync deletes + adds for "mv", direct is much faster as "mv" is supported by acd_cli and the acd api
    default.direct,
    maxProcesses = 1,
    -- we still run rsync on init, but once running, direct cp/mv/rm is used
    rsync = {
        dry_run = false,
        -- for additional debugging, set true
        verbose = false,
        update = true,
        times = true,
        perms = true,
        executability = true,
        owner = true,
        whole_file = true,
        hard_links = true,
        one_file_system = true,
        _extra = { "-g", "--inplace" },
        -- for additional debugging, enable stats/progress
        -- _extra =  {"-g", "--inplace", "--stats", "--progress"},
        sparse = false,
        acls = false,
        checksum = false,
        compress = false,
        copy_links = false,
        links = false,
    },
    _cmd = function(command)
        log("Normal", "> " .. command)
        local handle = io.popen(command)
        local result = handle:read("*a")
        handle:close()
        return result:match "^(.-)\n*$"
    end,
    _fs = function(path, fs)
        local result = acd._cmd("df -P -T " .. path .. " | tail -n1 | awk '{print $2}'")
        if result == fs then
            return true
        end
    end,
    prepare = function(config, level, skipTarget)
        -- MOUNT remote acd
        log("Normal", "Checking that acd is mounted")
        if acd._fs(config.acd_path, "fuse.ACDFuse") then
            log("Normal", "Found acd at " .. config.acd_path)
        else
            log("Normal", "Mounting acd at " .. config.acd_path)
            local result = acd._cmd("acd_cli mount " .. config.acd_path)
            if acd._fs(config.acd_path, "fuse.ACDFuse") ~= true then
                log("Error", "Unable to mount encfs filesystem, got fstype " .. result .. " at " .. config.target)
                log("Error", "Result" .. result)
                terminate(-1)
            end
        end

        -- MOUNT decrypted encfs passthru to encrypted ACD/encfs_src
        if config.acd_encfs_conf and config.acd_encfs_src then
            log("Normal", "Checking decrypted encfs passthrough to acd encrypted path")
            if acd._fs(config.target, "fuse.encfs") then
                log("Normal", "Found encfs mounted at " .. config.target)
            else
                log("Normal", "Checking target is empty " .. config.target)
                if acd._cmd("ls -A " .. config.target) ~= "" then
                    log("Error", "Cannot mount encfs to non-existing or non-empty directory " .. config.target)
                    terminate(-1)
                end
                if acd._cmd("ls -A " .. config.acd_encfs_conf) ~= config.acd_encfs_conf then
                    log("Error", "Cannot find encfs config " .. config.acd_encfs_conf)
                    terminate(-1)
                end

                log("Normal", "Mounting encfs with config " .. config.acd_encfs_conf)
                log("Normal", "Mounting encfs from sourch path " .. config.acd_encfs_src)
                log("Normal", "Mounting encfs to target " .. config.target)
                local result = acd._cmd("ENCFS6_CONFIG="
                        .. config.acd_encfs_conf
                        .. " encfs --extpass=\"zenity --password --title='LSyncd: Mount encfs acd'\" "
                        .. config.acd_encfs_src .. " "
                        .. config.target)
                if acd._fs(config.target, "fuse.encfs") then
                    log("Normal", "Mounted decrypted encfs from " .. config.acd_encfs_src .. " at " .. config.target)
                else
                    log("Error", "Unable to mount encfs " .. config.target)
                    log("Error", "Result: " .. result)
                    terminate(-1)
                end
            end
        end

        log("Normal", "Checking target is not empty " .. config.target)
        if acd._cmd("ls -A " .. config.target) == "" then
            log("Error", "Target is empty. Copy one file to ensure target is mounted as desired." .. config.target)
            terminate(-1)
        end

        log("Normal", "Initializing first rsync from " .. config.source .. " to " .. config.target)

        return default.rsync.prepare(config, level, skipTarget)
    end,
    checkgauge = {
        default.direct.checkgauge,
        _cmd = true,
        _fs = true,
        acd_path = true,
        acd_encfs_conf = true,
        acd_encfs_src = true,
    },
}

-- ## Configuration ##
--
-- == acd_path ==
-- Setup your acd_cli http://acd-cli.readthedocs.org/en/latest/setup.html
-- Authorize your computer to connect to your acd: http://acd-cli.readthedocs.org/en/latest/authorization.html
-- Ensure acd_cli mount works: acd_cli mount /path/to/acdRemoteMount
-- >> This is "acd_path"
--
-- == source ==
-- Make an empty local folder, e.g. /path/to/local/folder
--   >> This is "source"
--
-- == acd_encfs_conf ==
-- Make a file in the empty local folder, e.g. /path/to/local/folder/ThisIsMyAcdEncryptedRoot.txt
-- Setup encryption on the folder, mount it anywhere, e.g. /path/to/local/encryptedFolder
-- Move the .encfs6.xml file somewhere else (not on acd, not in the local folder) and backup the file somewhere else.
--   >> This is "acd_encfs_conf"
--
-- == acd_encfs_src ==
-- Copy the local/encryptedFolder to your acd, e.g. cp /path/to/local/encryptedFolder /path/to/acdRemoteMount/encryptedFolder
--   >> This is "acd_encfs_src"
--
-- == target ==
-- It should have had one file with a random looking name, about the same size as your txt file above.
-- Unmount the local/encryptedFolder mount, e.g. /path/to/local/encryptedFolder
-- Make a mount path for the decrypted mount of that remote folder, e.g. /path/to/acdRemoteFolderDecryptedMount
--   >> This is "target"
--
-- ## Testing ##
--
-- Ensure the decrypted mount contains your text file. Replace the "config.*" variables in the command below to test:
--   >> ENCFS6_CONFIG=config.acd_encfs_conf encfs config.acd_encfs_src config.target
--
-- You can unmount them both now. First the encfs, then the acd. Then you can run this lsyncd to boot them back up and sync.
-- Once it's running, you can drop files into your local/folder and they'll be encrypted and pushed to acd.
--
-- Thanks goes out to https://amc.ovh/2015/08/14/mounting-uploading-amazon-cloud-drive-encrypted.html
--
-- You could also setup local > localencfs (--reverse) > acd, but localencfs does not firing inotify to lsyncd
-- A more complex lsyncd that watches local, but does cp/mv/rm from localencfs to acd/encrypted_folder may also work
sync {
    acd,
    source = "/path/to/local/folder",
    acd_path = "/path/to/acdRemoteMount",
    acd_encfs_conf = "/path/to/local/.encfs6.xml",
    acd_encfs_src = "/path/to/acdRemoteMount/encryptedFolder",
    target = "/path/to/acdRemoteFolderDecryptedMount",
    delay = 2,
}
