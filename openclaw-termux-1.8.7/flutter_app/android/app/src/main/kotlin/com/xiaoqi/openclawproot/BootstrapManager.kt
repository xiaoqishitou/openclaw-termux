package com.xiaoqi.openclawproot

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.system.Os
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.util.zip.GZIPInputStream
import org.apache.commons.compress.archivers.ar.ArArchiveInputStream
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.compressors.xz.XZCompressorInputStream
import org.apache.commons.compress.compressors.zstandard.ZstdCompressorInputStream

class BootstrapManager(
    private val context: Context,
    private val filesDir: String,
    private val nativeLibDir: String
) {

    companion object {
        private const val TAG = "BootstrapManager"
        private const val IO_BUFFER_SIZE = 65536
        private const val IO_BUFFER_SIZE_LARGE = 256 * 1024

        private val SKIP_PREFIXES = setOf("dev/", "proc/", "sys/")
        private val SKIP_ENTRIES = setOf("dev", "proc", "sys")
    }

    private val rootfsDir get() = "$filesDir/rootfs/ubuntu"
    private val tmpDir get() = "$filesDir/tmp"
    private val homeDir get() = "$filesDir/home"
    private val configDir get() = "$filesDir/config"
    private val libDir get() = "$filesDir/lib"

    // ================================================================
    // Section 1: Directory Setup & Status
    // ================================================================

    fun setupDirectories() {
        listOf(rootfsDir, tmpDir, homeDir, configDir, "$homeDir/.openclaw", libDir).forEach {
            File(it).mkdirs()
        }
        setupLibtalloc()
        setupFakeSysdata()
    }

    private fun setupLibtalloc() {
        val source = File("$nativeLibDir/libtalloc.so")
        val target = File("$libDir/libtalloc.so.2")
        if (source.exists() && !target.exists()) {
            source.copyTo(target)
            target.setExecutable(true)
        }
    }

    fun isBootstrapComplete(): Boolean {
        return File(rootfsDir).exists()
            && File("$rootfsDir/bin/bash").exists()
            && File("$rootfsDir/root/.openclaw/bionic-bypass.js").exists()
            && File("$rootfsDir/usr/local/bin/node").exists()
            && File("$rootfsDir/usr/local/lib/node_modules/openclaw/package.json").exists()
    }

    fun getBootstrapStatus(): Map<String, Any> {
        val rootfsExists = File(rootfsDir).exists()
        val binBashExists = File("$rootfsDir/bin/bash").exists()
        val nodeExists = File("$rootfsDir/usr/local/bin/node").exists()
        val openclawExists = File("$rootfsDir/usr/local/lib/node_modules/openclaw/package.json").exists()
        val bypassExists = File("$rootfsDir/root/.openclaw/bionic-bypass.js").exists()

        return mapOf(
            "rootfsExists" to rootfsExists,
            "binBashExists" to binBashExists,
            "nodeInstalled" to nodeExists,
            "openclawInstalled" to openclawExists,
            "bypassInstalled" to bypassExists,
            "rootfsPath" to rootfsDir,
            "complete" to (rootfsExists && binBashExists && bypassExists
                && nodeExists && openclawExists)
        )
    }

    // ================================================================
    // Section 2: Rootfs Extraction
    // ================================================================

    fun extractRootfs(tarPath: String) {
        val rootfs = File(rootfsDir)
        if (rootfs.exists()) {
            deleteRecursively(rootfs)
        }
        rootfs.mkdirs()

        val deferredSymlinks = mutableListOf<Pair<String, String>>()
        var entryCount = 0
        var fileCount = 0
        var symlinkCount = 0
        var extractionError: Exception? = null

        try {
            openTarGzStream(tarPath).use { tis ->
                var entry: TarArchiveEntry? = tis.nextEntry
                while (entry != null) {
                    entryCount++
                    val name = sanitizeEntryName(entry.name)

                    if (shouldSkipEntry(name)) {
                        entry = tis.nextEntry
                        continue
                    }

                    val outFile = File(rootfsDir, name)

                    when {
                        entry.isDirectory -> {
                            outFile.mkdirs()
                        }
                        entry.isSymbolicLink -> {
                            deferredSymlinks.add(Pair(entry.linkName, outFile.absolutePath))
                            symlinkCount++
                        }
                        entry.isLink -> {
                            extractHardLink(entry, outFile)
                            fileCount++
                        }
                        else -> {
                            extractRegularFile(tis, outFile, name, entry.mode)
                            fileCount++
                        }
                    }

                    entry = tis.nextEntry
                }
            }
        } catch (e: Exception) {
            extractionError = e
        }

        if (entryCount == 0) {
            throw RuntimeException(
                "Extraction failed: tarball appears empty or corrupt. " +
                "Error: ${extractionError?.message ?: "none"}"
            )
        }

        if (extractionError != null && fileCount < 100) {
            throw RuntimeException(
                "Extraction failed after $entryCount entries ($fileCount files): " +
                "${extractionError!!.message}"
            )
        }

        createDeferredSymlinks(deferredSymlinks, symlinkCount)

        if (!File("$rootfsDir/bin/bash").exists() &&
            !File("$rootfsDir/usr/bin/bash").exists()) {
            throw RuntimeException(
                "Extraction failed: bash not found in rootfs. " +
                "Processed $entryCount entries, $fileCount files, " +
                "$symlinkCount symlinks. " +
                "Extraction error: ${extractionError?.message ?: "none"}"
            )
        }

        configureRootfs()
        File(tarPath).delete()
    }

    private fun createDeferredSymlinks(
        deferredSymlinks: List<Pair<String, String>>,
        totalCount: Int
    ) {
        var symlinkErrors = 0
        var lastSymlinkError = ""
        for ((target, path) in deferredSymlinks) {
            try {
                val file = File(path)
                if (file.exists()) {
                    if (file.isDirectory) {
                        mergeDirectoryToSymlinkTarget(file, target)
                        deleteRecursively(file)
                    } else {
                        file.delete()
                    }
                }
                file.parentFile?.mkdirs()
                Os.symlink(target, path)
            } catch (e: Exception) {
                symlinkErrors++
                lastSymlinkError = "$path -> $target: ${e.message}"
            }
        }
    }

    private fun mergeDirectoryToSymlinkTarget(dir: File, linkTarget: String) {
        val resolvedTarget = if (linkTarget.startsWith("/")) {
            linkTarget.removePrefix("/")
        } else {
            val parent = dir.parentFile?.absolutePath ?: rootfsDir
            File(parent, linkTarget).relativeTo(File(rootfsDir)).path
        }
        val realTargetDir = File(rootfsDir, resolvedTarget)
        if (realTargetDir.exists() && realTargetDir.isDirectory) {
            dir.listFiles()?.forEach { child ->
                val dest = File(realTargetDir, child.name)
                if (!dest.exists()) {
                    child.renameTo(dest)
                }
            }
        }
    }

    // ================================================================
    // Section 3: DEB Package Extraction
    // ================================================================

    fun extractDebPackages(): Int {
        val archivesDir = File("$rootfsDir/var/cache/apt/archives")
        if (!archivesDir.exists()) {
            throw RuntimeException("No apt archives directory found")
        }

        val debFiles = archivesDir.listFiles { f -> f.name.endsWith(".deb") }
            ?: throw RuntimeException("No .deb files found in apt cache")

        if (debFiles.isEmpty()) {
            throw RuntimeException("No .deb files found in apt cache")
        }

        var extracted = 0
        val errors = mutableListOf<String>()

        for (debFile in debFiles) {
            try {
                extractSingleDeb(debFile)
                extracted++
            } catch (e: Exception) {
                errors.add("${debFile.name}: ${e.message}")
            }
        }

        if (extracted == 0) {
            throw RuntimeException(
                "Failed to extract any .deb packages. Errors: ${errors.joinToString("; ")}"
            )
        }

        fixBinPermissions()
        return extracted
    }

    private fun extractSingleDeb(debFile: File) {
        FileInputStream(debFile).use { fis ->
            BufferedInputStream(fis, IO_BUFFER_SIZE_LARGE).use { bis ->
                ArArchiveInputStream(bis).use { arIn ->
                    var arEntry = arIn.nextEntry
                    while (arEntry != null) {
                        val arName = arEntry.name
                        if (arName.startsWith("data.tar")) {
                            val dataStream = openCompressedStream(arName, arIn)
                            extractTarToRootfs(dataStream, deferSymlinks = false)
                            return
                        }
                        arEntry = arIn.nextEntry
                    }
                }
            }
        }
    }

    // ================================================================
    // Section 4: Node.js Tarball Extraction
    // ================================================================

    fun extractNodeTarball(tarPath: String) {
        val destDir = File("$rootfsDir/usr/local")
        destDir.mkdirs()

        var entryCount = 0
        try {
            FileInputStream(tarPath).use { fis ->
                BufferedInputStream(fis, IO_BUFFER_SIZE_LARGE).use { bis ->
                    XZCompressorInputStream(bis).use { xzis ->
                        TarArchiveInputStream(xzis).use { tis ->
                            var entry: TarArchiveEntry? = tis.nextEntry
                            while (entry != null) {
                                entryCount++
                                val name = entry.name

                                val slashIdx = name.indexOf('/')
                                if (slashIdx < 0 || slashIdx == name.length - 1) {
                                    entry = tis.nextEntry
                                    continue
                                }
                                val relPath = name.substring(slashIdx + 1)
                                if (relPath.isEmpty()) {
                                    entry = tis.nextEntry
                                    continue
                                }

                                val outFile = File(destDir, relPath)

                                when {
                                    entry.isDirectory -> {
                                        outFile.mkdirs()
                                    }
                                    entry.isSymbolicLink -> {
                                        try {
                                            if (outFile.exists()) outFile.delete()
                                            outFile.parentFile?.mkdirs()
                                            Os.symlink(entry.linkName, outFile.absolutePath)
                                        } catch (_: Exception) {}
                                    }
                                    else -> {
                                        outFile.parentFile?.mkdirs()
                                        FileOutputStream(outFile).use { fos ->
                                            copyStream(tis, fos)
                                        }
                                        outFile.setReadable(true, false)
                                        outFile.setWritable(true, false)
                                        val mode = entry.mode
                                        if (mode and 0b001_001_001 != 0 ||
                                            relPath.startsWith("bin/") ||
                                            relPath.contains(".so")) {
                                            outFile.setExecutable(true, false)
                                        }
                                    }
                                }

                                entry = tis.nextEntry
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            throw RuntimeException(
                "Node.js tarball extraction failed after $entryCount entries: ${e.message}"
            )
        }

        val nodeBin = File("$rootfsDir/usr/local/bin/node")
        if (!nodeBin.exists()) {
            throw RuntimeException(
                "Node.js extraction failed: node binary not found at /usr/local/bin/node " +
                "(processed $entryCount entries)"
            )
        }
        nodeBin.setExecutable(true, false)

        File(tarPath).delete()
    }

    // ================================================================
    // Section 5: Rootfs Configuration
    // ================================================================

    private fun configureRootfs() {
        configureApt()
        configureDpkg()
        ensureEssentialDirectories()
        ensureMachineId()
        ensurePolicyRc()
        registerAndroidUsers()
        ensureHostsFile()
        ensureRootfsTmp()
        fixBinPermissions()
    }

    private fun configureApt() {
        val aptConfDir = File("$rootfsDir/etc/apt/apt.conf.d")
        aptConfDir.mkdirs()
        File(aptConfDir, "01-openclaw-proot").writeText(
            "APT::Sandbox::User \"root\";\n" +
            "Dpkg::Use-Pty \"0\";\n" +
            "Dpkg::Options { \"--force-confnew\"; \"--force-overwrite\"; };\n"
        )
    }

    private fun configureDpkg() {
        val dpkgConfDir = File("$rootfsDir/etc/dpkg/dpkg.cfg.d")
        dpkgConfDir.mkdirs()
        File(dpkgConfDir, "01-openclaw-proot").writeText(
            "force-unsafe-io\n" +
            "no-debsig\n" +
            "force-overwrite\n" +
            "force-depends\n" +
            "force-statoverride-add\n"
        )

        val statOverride = File("$rootfsDir/var/lib/dpkg/statoverride")
        if (statOverride.exists()) statOverride.writeText("")
    }

    private fun ensureEssentialDirectories() {
        listOf(
            "$rootfsDir/etc/ssl/certs",
            "$rootfsDir/usr/share/keyrings",
            "$rootfsDir/etc/apt/sources.list.d",
            "$rootfsDir/var/lib/dpkg/updates",
            "$rootfsDir/var/lib/dpkg/triggers",
            "$rootfsDir/tmp/npm-cache/_cacache/tmp",
            "$rootfsDir/tmp/npm-cache/_cacache/content-v2",
            "$rootfsDir/tmp/npm-cache/_cacache/index-v5",
            "$rootfsDir/tmp/npm-cache/_logs",
            "$rootfsDir/root/.npm",
            "$rootfsDir/root/.config",
            "$rootfsDir/usr/local/lib/node_modules",
            "$rootfsDir/usr/local/bin",
            "$rootfsDir/root/.openclaw",
            "$rootfsDir/root/.openclaw/data",
            "$rootfsDir/root/.openclaw/memory",
            "$rootfsDir/root/.openclaw/skills",
            "$rootfsDir/root/.openclaw/config",
            "$rootfsDir/root/.openclaw/extensions",
            "$rootfsDir/root/.openclaw/logs",
            "$rootfsDir/root/.config/openclaw",
            "$rootfsDir/root/.local/share",
            "$rootfsDir/root/.cache",
            "$rootfsDir/root/.cache/openclaw",
            "$rootfsDir/root/.cache/node",
            "$rootfsDir/var/tmp",
            "$rootfsDir/run",
            "$rootfsDir/run/lock",
            "$rootfsDir/dev/shm",
        ).forEach { File(it).mkdirs() }
    }

    private fun ensureMachineId() {
        val machineId = File("$rootfsDir/etc/machine-id")
        if (!machineId.exists()) {
            machineId.parentFile?.mkdirs()
            machineId.writeText("10000000000000000000000000000000\n")
        }
    }

    private fun ensurePolicyRc() {
        val policyRc = File("$rootfsDir/usr/sbin/policy-rc.d")
        policyRc.parentFile?.mkdirs()
        policyRc.writeText("#!/bin/sh\nexit 101\n")
        policyRc.setExecutable(true, false)
    }

    private fun ensureHostsFile() {
        val hosts = File("$rootfsDir/etc/hosts")
        if (!hosts.exists() || !hosts.readText().contains("localhost")) {
            hosts.writeText(
                "127.0.0.1   localhost.localdomain localhost\n" +
                "::1         localhost.localdomain localhost ip6-localhost ip6-loopback\n"
            )
        }
    }

    private fun ensureRootfsTmp() {
        val rootfsTmp = File("$rootfsDir/tmp")
        rootfsTmp.mkdirs()
        rootfsTmp.setReadable(true, false)
        rootfsTmp.setWritable(true, false)
        rootfsTmp.setExecutable(true, false)
    }

    // ================================================================
    // Section 6: Permission Fixes
    // ================================================================

    private fun fixBinPermissions() {
        val recursiveExecDirs = listOf(
            "$rootfsDir/usr/bin",
            "$rootfsDir/usr/sbin",
            "$rootfsDir/usr/local/bin",
            "$rootfsDir/usr/local/sbin",
            "$rootfsDir/usr/lib/apt/methods",
            "$rootfsDir/usr/lib/dpkg",
            "$rootfsDir/usr/lib/git-core",
            "$rootfsDir/usr/libexec",
            "$rootfsDir/var/lib/dpkg/info",
            "$rootfsDir/usr/share/debconf",
            "$rootfsDir/bin",
            "$rootfsDir/sbin",
        )
        for (dirPath in recursiveExecDirs) {
            val dir = File(dirPath)
            if (dir.exists() && dir.isDirectory) {
                fixExecRecursive(dir)
            }
        }

        val libDirs = listOf(
            "$rootfsDir/usr/lib",
            "$rootfsDir/lib",
        )
        for (dirPath in libDirs) {
            val dir = File(dirPath)
            if (dir.exists() && dir.isDirectory) {
                fixSharedLibsRecursive(dir)
            }
        }
    }

    private fun fixExecRecursive(dir: File) {
        dir.listFiles()?.forEach { file ->
            if (file.isDirectory) {
                fixExecRecursive(file)
            } else if (file.isFile) {
                file.setReadable(true, false)
                file.setExecutable(true, false)
            }
        }
    }

    private fun fixSharedLibsRecursive(dir: File) {
        dir.listFiles()?.forEach { file ->
            if (file.isDirectory) {
                fixSharedLibsRecursive(file)
            } else if (file.name.endsWith(".so") || file.name.contains(".so.")) {
                file.setReadable(true, false)
                file.setExecutable(true, false)
            }
        }
    }

    // ================================================================
    // Section 7: User/Group Registration
    // ================================================================

    private fun registerAndroidUsers() {
        val uid = android.os.Process.myUid()
        val gid = uid

        val dbFiles = listOf("passwd", "shadow", "group", "gshadow")
        for (dbName in dbFiles) {
            val f = File("$rootfsDir/etc/$dbName")
            if (f.exists()) f.setWritable(true, false)
        }

        registerPasswd(uid, gid)
        registerShadow()
        registerGroup(gid)
        registerGshadow()
    }

    private fun registerPasswd(uid: Int, gid: Int) {
        val passwd = File("$rootfsDir/etc/passwd")
        if (passwd.exists()) {
            val content = passwd.readText()
            if (!content.contains("aid_android")) {
                passwd.appendText("aid_android:x:$uid:$gid:Android:/:/sbin/nologin\n")
            }
        }
    }

    private fun registerShadow() {
        val shadow = File("$rootfsDir/etc/shadow")
        if (shadow.exists()) {
            val content = shadow.readText()
            if (!content.contains("aid_android")) {
                shadow.appendText("aid_android:*:18446:0:99999:7:::\n")
            }
        }
    }

    private fun registerGroup(gid: Int) {
        val group = File("$rootfsDir/etc/group")
        if (group.exists()) {
            val content = group.readText()
            val androidGroups = mapOf(
                "aid_inet" to 3003,
                "aid_net_raw" to 3004,
                "aid_sdcard_rw" to 1015,
                "aid_android" to gid,
            )
            for ((groupName, groupId) in androidGroups) {
                if (!content.contains(groupName)) {
                    group.appendText("$groupName:x:$groupId:root,aid_android\n")
                }
            }
        }
    }

    private fun registerGshadow() {
        val gshadow = File("$rootfsDir/etc/gshadow")
        if (gshadow.exists()) {
            val content = gshadow.readText()
            val gshadowEntries = listOf("aid_inet", "aid_net_raw", "aid_sdcard_rw", "aid_android")
            for (entryName in gshadowEntries) {
                if (!content.contains(entryName)) {
                    gshadow.appendText("$entryName:*::root,aid_android\n")
                }
            }
        }
    }

    // ================================================================
    // Section 8: Bionic Bypass & Runtime Scripts
    // ================================================================

    fun installBionicBypass() {
        val bypassDir = File("$rootfsDir/root/.openclaw")
        bypassDir.mkdirs()

        writeCwdFix(bypassDir)
        writeNodeWrapper(bypassDir)
        writeProotCompat(bypassDir)
        writeBionicBypass(bypassDir)
        writeGitConfig()
        patchBashrc()
        ensureOpenClawConfig(bypassDir)
    }

    private fun writeCwdFix(bypassDir: File) {
        File(bypassDir, "cwd-fix.js").writeText("""
// OpenClaw CWD Fix - Auto-generated
// proot on Android 10+ returns ENOSYS for getcwd() syscall.
// Patch process.cwd to return /root on failure.
const _origCwd = process.cwd;
process.cwd = function() {
  try { return _origCwd.call(process); }
  catch(e) { return process.env.HOME || '/root'; }
};
""".trimIndent())
    }

    private fun writeNodeWrapper(bypassDir: File) {
        File(bypassDir, "node-wrapper.js").writeText("""
// OpenClaw Node Wrapper - Auto-generated
// Patches broken proot syscalls, then loads the target script.
// Used for bootstrap-time npm operations.

// --- Load shared proot compatibility patches ---
require('/root/.openclaw/proot-compat.js');

// Load target script
const script = process.argv[2];
if (script) {
  process.argv = [process.argv[0], script, ...process.argv.slice(3)];
  require(script);
} else {
  console.log('Usage: node node-wrapper.js <script> [args...]');
  process.exit(1);
}
""".trimIndent())
    }

    private fun writeProotCompat(bypassDir: File) {
        File(bypassDir, "proot-compat.js").writeText("""
// OpenClaw Proot Compatibility Layer - Auto-generated
// Patches all known broken syscalls in proot on Android 10+.
// This file is require()'d by both node-wrapper.js and bionic-bypass.js.

'use strict';

// ====================================================================
// 1. process.cwd() â€?getcwd() returns ENOSYS in proot
// ====================================================================
const _origCwd = process.cwd;
process.cwd = function() {
  try { return _origCwd.call(process); }
  catch(e) { return process.env.HOME || '/root'; }
};

// ====================================================================
// 2. os module patches â€?various /proc reads fail in proot
// ====================================================================
const _os = require('os');

// os.hostname() â€?may fail reading /proc/sys/kernel/hostname
const _origHostname = _os.hostname;
_os.hostname = function() {
  try { return _origHostname.call(_os); }
  catch(e) { return 'localhost'; }
};

// os.tmpdir() â€?ensure it returns /tmp
const _origTmpdir = _os.tmpdir;
_os.tmpdir = function() {
  try {
    const t = _origTmpdir.call(_os);
    return t || '/tmp';
  } catch(e) { return '/tmp'; }
};

// os.homedir() â€?may fail with ENOSYS
const _origHomedir = _os.homedir;
_os.homedir = function() {
  try { return _origHomedir.call(_os); }
  catch(e) { return process.env.HOME || '/root'; }
};

// os.userInfo() â€?getpwuid may fail in proot
const _origUserInfo = _os.userInfo;
_os.userInfo = function(opts) {
  try { return _origUserInfo.call(_os, opts); }
  catch(e) {
    return {
      uid: 0, gid: 0,
      username: 'root',
      homedir: process.env.HOME || '/root',
      shell: '/bin/bash'
    };
  }
};

// os.cpus() â€?reading /proc/cpuinfo may fail
const _origCpus = _os.cpus;
_os.cpus = function() {
  try {
    const cpus = _origCpus.call(_os);
    if (cpus && cpus.length > 0) return cpus;
  } catch(e) {}
  return [{ model: 'ARM', speed: 2000, times: { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 } }];
};

// os.totalmem() / os.freemem() â€?reading /proc/meminfo may fail
const _origTotalmem = _os.totalmem;
_os.totalmem = function() {
  try { return _origTotalmem.call(_os); }
  catch(e) { return 4 * 1024 * 1024 * 1024; }
};
const _origFreemem = _os.freemem;
_os.freemem = function() {
  try { return _origFreemem.call(_os); }
  catch(e) { return 2 * 1024 * 1024 * 1024; }
};

// os.networkInterfaces() â€?Android blocks getifaddrs()
const _origNetIf = _os.networkInterfaces;
_os.networkInterfaces = function() {
  try {
    const ifaces = _origNetIf.call(_os);
    if (ifaces && Object.keys(ifaces).length > 0) return ifaces;
  } catch(e) {}
  return {
    lo: [{
      address: '127.0.0.1', netmask: '255.0.0.0', family: 'IPv4',
      mac: '00:00:00:00:00:00', internal: true, cidr: '127.0.0.1/8'
    }]
  };
};

// ====================================================================
// 3. fs.mkdir â€?mkdirat() returns ENOSYS in proot
// ====================================================================
const _fs = require('fs');
const _path = require('path');
const _origMkdirSync = _fs.mkdirSync;
_fs.mkdirSync = function(p, options) {
  try {
    return _origMkdirSync.call(_fs, p, options);
  } catch(e) {
    if (e.code === 'ENOSYS' || (e.code === 'ENOENT' && options && options.recursive)) {
      const parts = _path.resolve(String(p)).split(_path.sep).filter(Boolean);
      let current = '';
      for (const part of parts) {
        current += _path.sep + part;
        try { _origMkdirSync.call(_fs, current); }
        catch(e2) { if (e2.code !== 'EEXIST' && e2.code !== 'EISDIR') { /* skip */ } }
      }
      return undefined;
    }
    throw e;
  }
};
const _origMkdir = _fs.mkdir;
_fs.mkdir = function(p, options, cb) {
  if (typeof options === 'function') { cb = options; options = undefined; }
  try { _fs.mkdirSync(p, options); if (cb) cb(null); }
  catch(e) { if (cb) cb(e); else throw e; }
};
const _fsp = _fs.promises;
if (_fsp) {
  const _origMkdirP = _fsp.mkdir;
  _fsp.mkdir = async function(p, options) {
    try { return await _origMkdirP.call(_fsp, p, options); }
    catch(e) {
      if (e.code === 'ENOSYS' || (e.code === 'ENOENT' && options && options.recursive)) {
        _fs.mkdirSync(p, options); return undefined;
      }
      throw e;
    }
  };
}

// ====================================================================
// 4. fs.rename â€?renameat2() may ENOSYS in proot; fallback to copy+unlink
// ====================================================================
const _origRenameSync = _fs.renameSync;
_fs.renameSync = function(oldPath, newPath) {
  try { return _origRenameSync.call(_fs, oldPath, newPath); }
  catch(e) {
    if (e.code === 'ENOSYS' || e.code === 'EXDEV') {
      _fs.copyFileSync(oldPath, newPath);
      try { _fs.unlinkSync(oldPath); } catch(_) {}
      return;
    }
    throw e;
  }
};
const _origRename = _fs.rename;
_fs.rename = function(oldPath, newPath, cb) {
  _origRename.call(_fs, oldPath, newPath, function(err) {
    if (err && (err.code === 'ENOSYS' || err.code === 'EXDEV')) {
      try {
        _fs.copyFileSync(oldPath, newPath);
        try { _fs.unlinkSync(oldPath); } catch(_) {}
        if (cb) cb(null);
      } catch(e2) { if (cb) cb(e2); }
    } else { if (cb) cb(err); }
  });
};
if (_fsp) {
  const _origRenameP = _fsp.rename;
  _fsp.rename = async function(oldPath, newPath) {
    try { return await _origRenameP.call(_fsp, oldPath, newPath); }
    catch(e) {
      if (e.code === 'ENOSYS' || e.code === 'EXDEV') {
        await _fsp.copyFile(oldPath, newPath);
        try { await _fsp.unlink(oldPath); } catch(_) {}
        return;
      }
      throw e;
    }
  };
}

// ====================================================================
// 5. fs.chmod/chown â€?fchmodat/fchownat may fail; tolerate ENOSYS
// ====================================================================
for (const fn of ['chmod', 'chown', 'lchown']) {
  const origSync = _fs[fn + 'Sync'];
  if (origSync) {
    _fs[fn + 'Sync'] = function() {
      try { return origSync.apply(_fs, arguments); }
      catch(e) { if (e.code === 'ENOSYS') return; throw e; }
    };
  }
  const origAsync = _fs[fn];
  if (origAsync) {
    _fs[fn] = function() {
      const args = Array.from(arguments);
      const cb = typeof args[args.length - 1] === 'function' ? args.pop() : null;
      try { origSync.apply(_fs, args); if (cb) cb(null); }
      catch(e) { if (e.code === 'ENOSYS') { if (cb) cb(null); } else { if (cb) cb(e); else throw e; } }
    };
  }
}

// ====================================================================
// 6. fs.watch â€?inotify may fail; provide silent no-op fallback
// ====================================================================
const _origWatch = _fs.watch;
_fs.watch = function(filename, options, listener) {
  try { return _origWatch.call(_fs, filename, options, listener); }
  catch(e) {
    if (e.code === 'ENOSYS' || e.code === 'ENOSPC' || e.code === 'ENOENT') {
      const EventEmitter = require('events');
      const fake = new EventEmitter();
      fake.close = function() {};
      fake.ref = function() { return this; };
      fake.unref = function() { return this; };
      return fake;
    }
    throw e;
  }
};

// ====================================================================
// 7. child_process.spawn â€?handle ENOSYS (proot) and ENOENT (missing binary).
//    Command-aware mock:
//    - Side-effect cmds (git, cmake): return FAILURE (128)
//    - Everything else: return SUCCESS (0)
// ====================================================================
const _cp = require('child_process');
const _EventEmitter = require('events');

function _isSideEffectCmd(cmd) {
  const base = String(cmd).split('/').pop();
  return base === 'git' || base === 'cmake';
}

function _shouldMock(errCode, cmd) {
  if (errCode === 'ENOSYS') return true;
  if (errCode === 'ENOENT' && _isSideEffectCmd(cmd)) return true;
  return false;
}

function _makeFakeChild(exitCode) {
  const fake = new _EventEmitter();
  fake.stdout = new (require('stream').Readable)({ read() { this.push(null); } });
  fake.stderr = new (require('stream').Readable)({ read() { this.push(null); } });
  fake.stdin = new (require('stream').Writable)({ write(c,e,cb) { cb(); } });
  fake.pid = 0;
  fake.exitCode = null;
  fake.kill = function() { return false; };
  fake.ref = function() { return this; };
  fake.unref = function() { return this; };
  fake.connected = false;
  fake.disconnect = function() {};
  process.nextTick(() => {
    fake.exitCode = exitCode;
    fake.emit('close', exitCode, null);
  });
  return fake;
}

function _makeFakeSyncResult(code) {
  return { status: code, signal: null, stdout: Buffer.alloc(0),
           stderr: Buffer.alloc(0),
           pid: 0, output: [null, Buffer.alloc(0), Buffer.alloc(0)],
           error: null };
}

const _origSpawn = _cp.spawn;
_cp.spawn = function(cmd, args, options) {
  try {
    const child = _origSpawn.call(_cp, cmd, args, options);
    child.on('error', (err) => {
      if (_shouldMock(err.code, cmd)) {
        const code = _isSideEffectCmd(cmd) ? 128 : 0;
        child.emit('close', code, null);
      }
    });
    return child;
  } catch(e) {
    if (_shouldMock(e.code, cmd)) {
      return _makeFakeChild(_isSideEffectCmd(cmd) ? 128 : 0);
    }
    throw e;
  }
};
const _origSpawnSync = _cp.spawnSync;
_cp.spawnSync = function(cmd, args, options) {
  try {
    const r = _origSpawnSync.call(_cp, cmd, args, options);
    if (r.error && _shouldMock(r.error.code, cmd)) {
      return _makeFakeSyncResult(_isSideEffectCmd(cmd) ? 128 : 0);
    }
    return r;
  } catch(e) {
    if (_shouldMock(e.code, cmd)) {
      return _makeFakeSyncResult(_isSideEffectCmd(cmd) ? 128 : 0);
    }
    throw e;
  }
};
const _origExecFile = _cp.execFile;
_cp.execFile = function(file, args, options, cb) {
  if (typeof args === 'function') { cb = args; args = []; options = {}; }
  if (typeof options === 'function') { cb = options; options = {}; }
  try { return _origExecFile.call(_cp, file, args, options, cb); }
  catch(e) {
    if (_shouldMock(e.code, file)) {
      const code = _isSideEffectCmd(file) ? 128 : 0;
      if (cb) cb(code ? Object.assign(new Error('spawn failed'), {code:e.code}) : null, '', '');
      return;
    }
    throw e;
  }
};
const _origExecFileSync = _cp.execFileSync;
_cp.execFileSync = function(file, args, options) {
  try { return _origExecFileSync.call(_cp, file, args, options); }
  catch(e) {
    if (_shouldMock(e.code, file)) {
      if (_isSideEffectCmd(file)) throw e;
      return Buffer.alloc(0);
    }
    throw e;
  }
};
""".trimIndent())
    }

    private fun writeBionicBypass(bypassDir: File) {
        File(bypassDir, "bionic-bypass.js").writeText("""
// OpenClaw Bionic Bypass - Auto-generated
// Comprehensive runtime compatibility layer for proot on Android 10+.
// Loaded via NODE_OPTIONS before any application code runs.

// Load all proot compatibility patches (shared with node-wrapper.js)
require('/root/.openclaw/proot-compat.js');
""".trimIndent())
    }

    private fun writeGitConfig() {
        val gitConfig = File("$rootfsDir/root/.gitconfig")
        gitConfig.writeText(
            "[url \"https://github.com/\"]\n" +
            "\tinsteadOf = ssh://git@github.com/\n" +
            "\tinsteadOf = git@github.com:\n" +
            "[advice]\n" +
            "\tdetachedHead = false\n"
        )
    }

    private fun patchBashrc() {
        val bashrc = File("$rootfsDir/root/.bashrc")
        val exportLine = "export NODE_OPTIONS=\"--require /root/.openclaw/bionic-bypass.js\""
        val existing = if (bashrc.exists()) bashrc.readText() else ""
        if (!existing.contains("bionic-bypass")) {
            bashrc.appendText("\n# OpenClaw Bionic Bypass\n$exportLine\n")
        }
    }

    private fun ensureOpenClawConfig(bypassDir: File) {
        val configFile = File(bypassDir, "openclaw.json")
        if (!configFile.exists()) {
            configFile.writeText("""
{
  "gateway": {
    "mode": "local"
  }
}
""".trimIndent())
            return
        }

        try {
            val content = configFile.readText()
            val json = org.json.JSONObject(content)
            var modified = false

            if (!json.has("gateway")) {
                json.put("gateway", org.json.JSONObject().put("mode", "local"))
                modified = true
            } else {
                val gw = json.getJSONObject("gateway")
                if (!gw.has("mode")) {
                    gw.put("mode", "local")
                    modified = true
                }
            }

            if (json.has("models")) {
                val models = json.optJSONObject("models")
                val providers = models?.optJSONObject("providers")
                if (providers != null) {
                    val providerKeys = providers.keys()
                    while (providerKeys.hasNext()) {
                        val providerKey = providerKeys.next()
                        val prov = providers.optJSONObject(providerKey)
                        val modelArr = prov?.optJSONArray("models")
                        if (modelArr != null) {
                            for (i in 0 until modelArr.length()) {
                                val item = modelArr.get(i)
                                when {
                                    item is String -> {
                                        modelArr.put(i, org.json.JSONObject()
                                            .put("id", item)
                                            .put("name", item))
                                        modified = true
                                    }
                                    item is org.json.JSONObject -> {
                                        val obj = item as org.json.JSONObject
                                        if (obj.has("id") && !obj.has("name")) {
                                            obj.put("name", obj.getString("id"))
                                            modified = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if (modified) {
                configFile.writeText(json.toString(2))
            }
        } catch (_: Exception) {}
    }

    // ================================================================
    // Section 9: DNS Configuration
    // ================================================================

    fun writeResolvConf() {
        val content = getSystemDnsServers()
        try {
            val dir = File(context.filesDir, "config")
            dir.mkdirs()
            File(dir, "resolv.conf").writeText(content)
        } catch (_: Exception) {
            File(configDir).mkdirs()
            File(configDir, "resolv.conf").writeText(content)
        }

        try {
            val rootfsResolv = File(rootfsDir, "etc/resolv.conf")
            rootfsResolv.parentFile?.mkdirs()
            rootfsResolv.writeText(content)
        } catch (_: Exception) {}
    }

    private fun getSystemDnsServers(): String {
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            if (cm != null) {
                val network = cm.activeNetwork
                if (network != null) {
                    val linkProps: LinkProperties? = cm.getLinkProperties(network)
                    val dnsServers = linkProps?.dnsServers
                    if (dnsServers != null && dnsServers.isNotEmpty()) {
                        val lines = dnsServers.joinToString("\n") { "nameserver ${it.hostAddress}" }
                        return "$lines\nnameserver 8.8.8.8\n"
                    }
                }
            }
        } catch (_: Exception) {}
        return "nameserver 8.8.8.8\nnameserver 8.8.4.4\n"
    }

    // ================================================================
    // Section 10: Fake /proc & /sys Data
    // ================================================================

    fun setupFakeSysdata() {
        val procDir = File("$configDir/proc_fakes")
        val sysDir = File("$configDir/sys_fakes")
        procDir.mkdirs()
        sysDir.mkdirs()

        File(procDir, "loadavg").writeText("0.12 0.07 0.02 2/165 765\n")

        File(procDir, "stat").writeText(
            "cpu  1957 0 2877 93280 262 342 254 87 0 0\n" +
            "cpu0 31 0 226 12027 82 10 4 9 0 0\n" +
            "cpu1 45 0 290 11498 21 9 8 7 0 0\n" +
            "cpu2 52 0 401 11730 36 15 6 10 0 0\n" +
            "cpu3 42 0 268 11677 31 12 5 8 0 0\n" +
            "cpu4 789 0 720 11364 26 100 83 18 0 0\n" +
            "cpu5 486 0 438 11685 42 86 60 13 0 0\n" +
            "cpu6 314 0 336 11808 45 68 52 11 0 0\n" +
            "cpu7 198 0 198 11491 25 42 36 11 0 0\n" +
            "intr 63361 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0\n" +
            "ctxt 38014093\n" +
            "btime 1694292441\n" +
            "processes 26442\n" +
            "procs_running 1\n" +
            "procs_blocked 0\n" +
            "softirq 75663 0 5903 6 25375 10774 0 243 11685 0 21677\n"
        )

        File(procDir, "uptime").writeText("124.08 932.80\n")

        File(procDir, "version").writeText(
            "Linux version ${ProcessManager.FAKE_KERNEL_RELEASE} (proot@termux) " +
            "(gcc (GCC) 13.3.0, GNU ld (GNU Binutils) 2.42) " +
            "${ProcessManager.FAKE_KERNEL_VERSION}\n"
        )

        File(procDir, "vmstat").writeText(
            "nr_free_pages 1743136\n" +
            "nr_zone_inactive_anon 179281\n" +
            "nr_zone_active_anon 7183\n" +
            "nr_zone_inactive_file 22858\n" +
            "nr_zone_active_file 51328\n" +
            "nr_zone_unevictable 642\n" +
            "nr_zone_write_pending 0\n" +
            "nr_mlock 0\n" +
            "nr_slab_reclaimable 7520\n" +
            "nr_slab_unreclaimable 10776\n" +
            "pgpgin 198292\n" +
            "pgpgout 7674\n" +
            "pswpin 0\n" +
            "pswpout 0\n" +
            "pgalloc_dma 0\n" +
            "pgalloc_dma32 0\n" +
            "pgalloc_normal 44669136\n" +
            "pgfree 46674674\n" +
            "pgactivate 1085674\n" +
            "pgdeactivate 340776\n" +
            "pglazyfree 139872\n" +
            "pgfault 37291463\n" +
            "pgmajfault 6854\n" +
            "pgrefill 480634\n"
        )

        File(procDir, "cap_last_cap").writeText("40\n")
        File(procDir, "max_user_watches").writeText("4096\n")
        File(procDir, "fips_enabled").writeText("0\n")
        File(sysDir, "empty").writeText("")
    }

    // ================================================================
    // Section 11: NPM Bin Wrappers
    // ================================================================

    fun createBinWrappers(packageName: String) {
        val pkgDir = File("$rootfsDir/usr/local/lib/node_modules/$packageName")
        val pkgJson = File(pkgDir, "package.json")
        if (!pkgJson.exists()) {
            throw RuntimeException("Package not found: $pkgDir")
        }

        val json = pkgJson.readText()
        val binDir = File("$rootfsDir/usr/local/bin")
        binDir.mkdirs()

        val binEntries = parseBinField(json, packageName)

        if (binEntries.isEmpty()) {
            for (candidate in listOf("bin/$packageName.js", "bin/$packageName", "cli.js", "index.js")) {
                if (File(pkgDir, candidate).exists()) {
                    binEntries[packageName] = candidate
                    break
                }
            }
        }

        for ((binName, relPath) in binEntries) {
            val binFile = File(binDir, binName)
            if (binFile.exists() && binFile.canExecute()) continue

            val target = "/usr/local/lib/node_modules/$packageName/$relPath"
            val wrapper = "#!/bin/sh\nexec node \"$target\" \"\$@\"\n"
            binFile.writeText(wrapper)
            binFile.setExecutable(true, false)
            binFile.setReadable(true, false)
        }
    }

    private fun parseBinField(json: String, packageName: String): MutableMap<String, String> {
        val binEntries = mutableMapOf<String, String>()
        val binMatch = Regex(""""bin"\s*:\s*(\{[^}]*\}|"[^"]*")""").find(json)
        if (binMatch != null) {
            val value = binMatch.groupValues[1]
            if (value.startsWith("{")) {
                Regex(""""([^"]+)"\s*:\s*"([^"]+)"""").findAll(value).forEach {
                    binEntries[it.groupValues[1]] = it.groupValues[2]
                }
            } else {
                val path = value.trim('"')
                binEntries[packageName] = path
            }
        }
        return binEntries
    }

    // ================================================================
    // Section 12: Rootfs File I/O
    // ================================================================

    fun readRootfsFile(path: String): String? {
        val file = File("$rootfsDir/$path")
        return if (file.exists()) file.readText() else null
    }

    fun writeRootfsFile(path: String, content: String) {
        val file = File("$rootfsDir/$path")
        file.parentFile?.mkdirs()
        file.writeText(content)
    }

    // ================================================================
    // Section 13: Asset Management
    // ================================================================

    fun copyBundledAsset(assetPath: String, destPath: String): Boolean {
        return try {
            val destFile = File(destPath)
            if (destFile.exists() && destFile.length() > 0L) {
                true
            } else {
                context.assets.open(assetPath).use { input ->
                    destFile.parentFile?.mkdirs()
                    FileOutputStream(destFile).use { output ->
                        input.copyTo(output)
                    }
                }
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    fun hasBundledAsset(assetPath: String): Boolean {
        return try {
            context.assets.open(assetPath).close()
            true
        } catch (_: Exception) {
            false
        }
    }

    // ================================================================
    // Section 14: Shared Extraction Helpers
    // ================================================================

    private fun sanitizeEntryName(name: String): String {
        return name.removePrefix("./").removePrefix("/")
    }

    private fun shouldSkipEntry(name: String): Boolean {
        if (name.isEmpty()) return true
        for (prefix in SKIP_PREFIXES) {
            if (name.startsWith(prefix)) return true
        }
        return name in SKIP_ENTRIES
    }

    private fun extractHardLink(entry: TarArchiveEntry, outFile: File) {
        val target = sanitizeEntryName(entry.linkName)
        val targetFile = File(rootfsDir, target)
        outFile.parentFile?.mkdirs()
        try {
            if (targetFile.exists()) {
                targetFile.copyTo(outFile, overwrite = true)
                if (targetFile.canExecute()) {
                    outFile.setExecutable(true, false)
                }
            }
        } catch (_: Exception) {}
    }

    private fun extractRegularFile(
        tis: TarArchiveInputStream,
        outFile: File,
        name: String,
        mode: Int
    ) {
        outFile.parentFile?.mkdirs()
        FileOutputStream(outFile).use { fos ->
            copyStream(tis, fos)
        }
        outFile.setReadable(true, false)
        outFile.setWritable(true, false)
        if (shouldSetExecutable(mode, name)) {
            outFile.setExecutable(true, false)
        }
    }

    private fun shouldSetExecutable(mode: Int, name: String): Boolean {
        if (mode and 0b001_001_001 != 0) return true
        if (mode == 0) {
            val path = name.lowercase()
            return path.contains("/bin/") ||
                path.contains("/sbin/") ||
                path.endsWith(".sh") ||
                path.contains("/lib/apt/methods/")
        }
        return false
    }

    private fun copyStream(input: InputStream, output: FileOutputStream) {
        val buf = ByteArray(IO_BUFFER_SIZE)
        var len: Int
        while (input.read(buf).also { len = it } != -1) {
            output.write(buf, 0, len)
        }
    }

    private fun openTarGzStream(tarPath: String): TarArchiveInputStream {
        val fis = FileInputStream(tarPath)
        val bis = BufferedInputStream(fis, IO_BUFFER_SIZE_LARGE)
        val gis = GZIPInputStream(bis)
        return TarArchiveInputStream(gis)
    }

    private fun openCompressedStream(name: String, arIn: ArArchiveInputStream): InputStream {
        return when {
            name.endsWith(".xz") -> XZCompressorInputStream(arIn)
            name.endsWith(".gz") -> GZIPInputStream(arIn)
            name.endsWith(".zst") -> ZstdCompressorInputStream(arIn)
            else -> arIn
        }
    }

    private fun extractTarToRootfs(dataStream: InputStream, deferSymlinks: Boolean) {
        TarArchiveInputStream(dataStream).use { tarIn ->
            var tarEntry: TarArchiveEntry? = tarIn.nextEntry
            while (tarEntry != null) {
                val entryName = sanitizeEntryName(tarEntry.name)

                if (entryName.isEmpty()) {
                    tarEntry = tarIn.nextEntry
                    continue
                }

                val outFile = File(rootfsDir, entryName)

                when {
                    tarEntry.isDirectory -> {
                        outFile.mkdirs()
                    }
                    tarEntry.isSymbolicLink -> {
                        if (deferSymlinks) {
                            try {
                                if (outFile.exists()) outFile.delete()
                                outFile.parentFile?.mkdirs()
                                Os.symlink(tarEntry.linkName, outFile.absolutePath)
                            } catch (_: Exception) {}
                        } else {
                            try {
                                if (outFile.exists()) outFile.delete()
                                outFile.parentFile?.mkdirs()
                                Os.symlink(tarEntry.linkName, outFile.absolutePath)
                            } catch (_: Exception) {}
                        }
                    }
                    tarEntry.isLink -> {
                        extractHardLink(tarEntry, outFile)
                    }
                    else -> {
                        extractRegularFile(tarIn, outFile, entryName, tarEntry.mode)
                    }
                }

                tarEntry = tarIn.nextEntry
            }
        }
    }

    // ================================================================
    // Section 15: Safe Delete
    // ================================================================

    private fun deleteRecursively(file: File) {
        try {
            if (!file.canonicalPath.startsWith(filesDir)) {
                return
            }
        } catch (_: Exception) {
            return
        }

        try {
            val path = file.toPath()
            if (java.nio.file.Files.isSymbolicLink(path)) {
                file.delete()
                return
            }
        } catch (_: Exception) {}

        if (file.isDirectory) {
            file.listFiles()?.forEach { deleteRecursively(it) }
        }
        file.delete()
    }
}
