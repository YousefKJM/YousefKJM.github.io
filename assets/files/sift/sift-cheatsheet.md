# SIFT Workstation Cheat Sheet

Login: `sansforensics` / `forensics` · elevate with `sudo -i`
Keep evidence read-only. Work on copies. Hash everything.

## Mount evidence read-only
```bash
# E01 -> raw
ewfmount evidence.E01 /mnt/ewf                      # exposes /mnt/ewf/ewf1
mmls /mnt/ewf/ewf1                                  # list partitions, note start sector
mount -o ro,loop,offset=$((2048*512)),show_sys_files /mnt/ewf/ewf1 /mnt/windows
# raw/dd image partition
mount -o ro,loop,offset=$((2048*512)) disk.dd /mnt/windows
# BitLocker
dislocker -r -V disk.dd -p<recovery-key> -- /mnt/bde && mount -o ro,loop /mnt/bde/dislocker-file /mnt/windows
# VSS (shadow copies)
vshadowmount /mnt/ewf/ewf1 /mnt/vss && mount -o ro,loop,show_sys_files /mnt/vss/vss1 /mnt/vss_mount
```

## Image a disk
```bash
ewfacquire /dev/sdX                                 # guided E01 with hashes
dcfldd if=/dev/sdX of=disk.dd hash=sha256 hashlog=disk.hashes bs=4M
sha256sum disk.dd
```

## File system & carving
```bash
fls -r -m / -o 2048 disk.dd > bodyfile              # list files (TSK)
icat -o 2048 disk.dd <inode> > recovered.bin        # extract by inode
foremost -t all -i disk.dd -o carved/               # header-based carving
bulk_extractor -o bulk/ disk.dd                     # emails, URLs, CCNs, etc.
```

## Super timeline (Plaso)
```bash
log2timeline.py --storage-file case.plaso /mnt/windows
psort.py -o l2tcsv -w timeline.csv case.plaso "date > '2025-08-01'"
psteal.py --source /mnt/windows -o l2tcsv -w quick.csv     # one-shot collect+sort
```

## Windows artifacts (Eric Zimmerman tools, /usr/local/bin wrappers)
```bash
MFTECmd -f /mnt/windows/\$MFT --csv out/             # $MFT
EvtxECmd -d /mnt/windows/Windows/System32/winevt/Logs --csv out/
RECmd --bn BatchExamples/... -d /mnt/windows/Windows/System32/config    # registry
AmcacheParser -f .../Amcache.hve --csv out/
JLECmd / LECmd / RBCmd / PECmd                       # jump lists, LNK, recycle bin, prefetch
```

## Registry (RegRipper)
```bash
rip.pl -r /mnt/windows/Windows/System32/config/SYSTEM -f system > system.txt
rip.pl -r .../NTUSER.DAT -f ntuser > ntuser.txt
```

## Memory (Volatility 3)
```bash
vol -f mem.raw windows.info
vol -f mem.raw windows.pslist
vol -f mem.raw windows.pstree
vol -f mem.raw windows.netscan
vol -f mem.raw windows.malfind
vol -f mem.raw windows.cmdline
vol -f mem.raw windows.dumpfiles --pid <pid>
```

## Other quick wins
```bash
regripper / amcacheparser / prefetch.py / usnparser / analyzemft / hindsight
clamscan -r -i /mnt/windows                          # known malware
exiftool suspicious.docx                             # metadata
pdf-parser.py / pdfid.py suspicious.pdf              # malicious PDFs
```
