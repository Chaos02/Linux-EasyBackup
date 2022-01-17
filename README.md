
# Linux-EasyBackup
```
Usage: ${execname} [OPTION]...
Clone entire disks reliably, with a test mode
	a, --adjust	adjust partition sizes without prompt (includes -c)
	c, --create	create partitions without prompt
	e, --exclude=	exclude partitions from clone delimited by ','
	f, --force	clone even if disconnected from main power or 
			  the specified disk identifier is not found
	h, --help	prints this help
	i, --install	opens dialog to install ${execname} to bin or 
			  privatebin optionally
			  and or schedules to run during Read only phase of boot
			  with anacron
	r, --resolve	resolves faulty gpt without prompt
	s, --source=	specifies source like 'sda'
	t, --target=	specifies target like 'nvme0'
	   --serial=	specifies a serial number to check if [TARGET]
				  is really the disk meant.
				  Serial number can be optained through:
	   --getSerial=[TARGET]
				  or
				  'udevadm info --query=all --name=/dev/[TARGET] -x | grep ID_SERIAL='
	w, --write	stop simulating the actions 
Exit status:
 0  if OK,
 1  if supressed by Hardware state (POWER,DISK)
 2  if major problem (e.g., cannot proccess flag; clone failed; etc)
(A Log should have been written to ${LogPath})
```
