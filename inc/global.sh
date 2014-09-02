#!/bin/bash

##
## Create an case senitive disk image and mount it to /Volumes/[ImageName]
## 
create_image(){
	
	# Create image if not exists 
	echo "Create Case-Sensitive Disk Image" 2>&1 | tee -a $glb_build_log 
	if [ ! -f "${glb_disk_image_name}.sparseimage" ]; then
		hdiutil create "${glb_disk_image_name}.sparseimage" \
			-type SPARSE \
			-fs JHFS+X \
			-size ${glb_disk_image_size} \
			-volname ${glb_disk_image_name} || exit 1
	else
		echo "already exists" 2>&1 | tee -a $glb_build_log
	fi
	
	# Mount image
	echo -n "Mounting image... " 2>&1 | tee -a $glb_build_log
	if [ ! -d "${glb_disk_image_path}" ]; then 
		hdiutil attach ${glb_disk_image_name}.sparseimage -mountroot $BASEPATH >/dev/null 2>&1 || exit 1
		echo "mounted to ${glb_disk_image_path}" 2>&1 | tee -a $glb_build_log
	else
		echo "already mounted to ${glb_disk_image_path}" 2>&1 | tee -a $glb_build_log
	fi
	
	# Create "kernel-build" directory if not exist
	echo -n "Create kernel build directory... " 2>&1 | tee -a $glb_build_log 
	if [ -d "${glb_disk_image_path}/build" ]; then
		rm -rf ${glb_disk_image_path}/build
	fi
	mkdir ${glb_disk_image_path}/build || exit 1
	echo "done" 2>&1 | tee -a $glb_build_log
}


##
## Create directories
## 
create_dir_structure(){
			
	# Create "download" directory if not exist
	echo -n "Create download directory... " 
	if [ ! -d "${glb_download_path}" ]; then
		mkdir -p ${glb_download_path} || exit 1
		echo "done" 
	else
		echo "already exists" 
	fi 

	# Create "src" directory if not exist	
	echo -n "Create source directory... " 
	if [ ! -d "${glb_source_path}" ]; then
		mkdir -p ${glb_source_path} || exit 1
		echo "done" 
	else
		echo "already exists" 
	fi 
	
	# Create "build" directory if not exist
	echo -n "Create build directory... " 
	if [ -d "${glb_build_path}" ]; then
		rm -rf ${glb_build_path}
	fi
	mkdir -p ${glb_build_path} || exit 1
	mkdir -p ${glb_build_path}/static || exit 1
	mkdir -p ${glb_build_path}/gcc-core-static || exit 1
	mkdir -p ${glb_build_path}/gcc-core-shared || exit 1
	mkdir -p ${glb_build_path}/build-kernel-headers || exit 1
	echo "done" 


	# Create "install" directory if not exist	
	echo -n "Create install directory... " 
	if [ -d "${glb_prefix}" ]; then
		rm -rf ${glb_prefix}
	fi
	mkdir -p ${glb_prefix} || exit 1
	mkdir -p ${glb_prefix}/arm-linux-gnueabihf || exit 1
	echo "done" 
	
	
	# Create "log" directory if not exist	
	echo -n "Create log directory... " 
	if [ -d "${glb_log_path}" ]; then
		rm -rf ${glb_log_path}
	fi
	mkdir -p ${glb_log_path} || exit 1
	touch ${glb_build_log}
	echo "done" 
	
	rm -f "$BASEPATH/${glb_build_name}-mac.zip"
	rm -f "$BASEPATH/${glb_build_name}.dmg"
}


## 
## Check if Xcode Command Line Tools are installd.
## If not try to install Command Line Tools
##
check_for_Command_Line_Tools(){
	
	echo -n "Checking for Xcode Command Line Tools... " 2>&1 | tee -a $glb_build_log
	
	if [ ! -f "/Library/Developer/CommandLineTools/usr/bin/gcc" ]; then
		
		echo "not installed" 2>&1 | tee -a $glb_build_log
		echo "Command Line Tools are required for the following steps." 2>&1 | tee -a $glb_build_log
		
		while true; do
		
			read -p "Install Command Line Tools or cancel the script? [I/c] " Ic
		
			Ic=${Ic:-I}
			case $Ic in
				[Ii]* ) install_Command_Line_Tools; break;;
				[Cc]* ) exit 0;;
					* ) echo "Please answer I (Install) or c (cancel).";;
			esac
		done
	else
		echo "installed" 2>&1 | tee -a $glb_build_log
	fi
}


##
## Install Xcode Command Line Tools
## Script will be abort for this stepp
##
install_Command_Line_Tools(){

	echo -n "Installing Command Line Tools... "
	
	# Install Command Line Tools
	xcode-select --install 
	
	echo "Please wait until the command line tools has been installed and run the script again!"
	
	# Script musz be abort at this point, because the installer will not halt the script
	exit 0
}


##
## Stripping all toolchain executables
##
strip_bin(){

	echo -n "Stripping all toolchain executables... " 2>&1 | tee -a $glb_build_log

	# Stripping files in bin
	FILES="${glb_prefix}/bin/*"
	for f in $FILES; do
		strip $f >/dev/null 2>&1 >> $glb_build_log
	done
	
	# Stripping files in TARGET/bin
	FILES="${glb_prefix}/${glb_target}/bin/*"
	for f in $FILES; do
		strip $f >/dev/null >/dev/null 2>&1 >> $glb_build_log
	done
	
	# Stripping files in libexec/gcc/TARGET
	FILES="${glb_prefix}/libexec/gcc/${glb_target}/4.8.2/*"
	for f in $FILES; do
		strip $f >/dev/null >/dev/null 2>&1 >> $glb_build_log
	done
	
	echo "done"
}


##
## End of the build
##
finish_build(){
	
	cd ${BASEPATH}

	# Create compressed archive
	echo -n "Create compressed archive... " 
	mkdir -p "${BASEPATH}/image"
	mv ${glb_prefix} "${BASEPATH}/image/${glb_build_name}"
	hdiutil \
		create "./${glb_build_name}.dmg" \
		-srcfolder "${BASEPATH}/image" \
		-volname ${glb_build_name}  >/dev/null 2>&1
	zip -r -X "${glb_build_name}-mac.zip" "${glb_build_name}.dmg" >/dev/null
	rm -rf "${glb_build_name}.dmg" >/dev/null 2>&1
	mv "${BASEPATH}/image/${glb_build_name}" ${glb_prefix}
	rm -rf "${BASEPATH}/image"
	echo "done" 
	
	cd $BASEPATH
	
	echo "Cleaning-up the build directory:"
	
	# Compress all log files 
	echo -n "Compress log files... " 
	FILES="${glb_log_path}/*.log"
	for f in $FILES; do
		zip -X "${f}.zip" $f >/dev/null 2>&1
		rm -f $f >/dev/null 2>&1
	done
	echo "done"
	
	echo -n "Delete unnecessary archives from the download directory... " 
	FILES="${glb_download_path}/*"
	for f in $FILES; do
		
		if [ $f != "${glb_download_path}/${glb_linaro_src1_arch}" ] \
		&& [ $f != "${glb_download_path}/${glb_linaro_src2_arch}" ] \
		&& [ $f != "${glb_download_path}/${glb_zlib_arch}" ] \
		&& [ $f != "${glb_download_path}/${glb_ncurses_arch}" ] ; then
			rm -rf $f >/dev/null 2>&1
		fi
	done
	echo "done"
	
	echo -n "Delete build directory... " 
	rm -rf $glb_build_path >/dev/null 2>&1
	echo "done"
	
	while true; do
		read -p "Delete source directory? [Y/n] " Yn
		Yn=${Yn:-Y}
		case $Yn in
			[Yy]* ) \
				echo -n "Delete source directory... "; \
				rm -rf $glb_source_path; \
				echo "done"; break;;
			[Nn]* ) break;;
				* ) echo "Please answer Y (Yes) or n (No).";;
		esac
	done
	
	echo -n "Unmount image... " 
	hdiutil detach $glb_disk_image_path >/dev/null 2>&1
	echo "done" 
	
	while true; do
		read -p "Delete Case-Sensitive Disk Image? [Y/n] " Yn
		Yn=${Yn:-Y}
		case $Yn in
			[Yy]* ) echo -n "Delete disk image... "; \
			rm -rf "${glb_disk_image_name}.sparseimage"; \
			echo "done"; break;;
			[Nn]* ) break;;
				* ) echo "Please answer Y (Yes) or n (No).";;
		esac
	done
	
	cd $BASEPATH
	
	while true; do
		read -p "Install tool-chains now? [Y/n] " Yn
		Yn=${Yn:-Y}
		case $Yn in
			[Yy]* ) \
				echo -n "Install tool-chains... "; \
				mv "./${glb_build_name}" "./gcc-${glb_target}"; \
				mv "gcc-${glb_target}" "/usr/local/";\
				glb_prefix="/usr/local/gcc-${glb_target}"
				echo "done"; break;;
			[Nn]* ) break;;
				* ) echo "Please answer Y (Yes) or n (No).";;
		esac
	done
}
