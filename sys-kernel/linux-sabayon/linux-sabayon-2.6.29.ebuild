# Copyright 2007 Sabayon Linux
# Distributed under the terms of the GNU General Public License v2

ETYPE="sources"
K_WANT_GENPATCHES=""
K_GENPATCHES_VER=""
inherit kernel-2
detect_version
detect_arch

UNIPATCH_STRICTORDER="yes"
KEYWORDS="amd64 x86"
HOMEPAGE="http://www.sabayonlinux.org"
DEPEND="
	!only_sources? ( <sys-kernel/genkernel-3.4.11 )
	splash? ( || ( x11-themes/sabayonlinux-artwork x11-themes/sabayon-artwork ) )
	<sys-kernel/genkernel-3.4.11"
RDEPEND="grub? ( sys-boot/grub )"
IUSE="splash dmraid grub no_sources only_sources"
RESTRICT="nomirror"

DESCRIPTION="Official Sabayon Linux Standard kernel image and source"
KV_FULL=${KV_FULL/linux/sabayon}
K_NOSETEXTRAVERSION="1"
EXTRAVERSION=${EXTRAVERSION/linux/sabayon}
SLOT="${PV}"
S="${WORKDIR}/linux-${KV_FULL}"

## INIT: Exported data
# SL_PATCHES_URI=""
# SUSPEND2_TARGET="${PV}"
# SUSPEND2_SRC="current-tuxonice-for-${SUSPEND2_TARGET}.patch.bz2"
# SUSPEND2_URI="http://www.tuxonice.net/downloads/all/${SUSPEND2_SRC}"

UNIPATCH_LIST="
 	${FILESDIR}/${PV}/${P}-aufs.patch.bz2
	${FILESDIR}/${PV}/current-tuxonice-for-head.patch-20090313-v1.bz2
"


# gentoo patches
for patch in `find ${FILESDIR}/${PV}/genpatches -iname "*.patch*" | sort -n`; do
	UNIPATCH_LIST="${UNIPATCH_LIST} ${patch}"
done

# mactel patches
for patch in `find ${FILESDIR}/${PV}/mactel -iname "*.patch*" | sort -n`; do
	UNIPATCH_LIST="${UNIPATCH_LIST} ${patch}"
done


SRC_URI="${KERNEL_URI} ${SL_PATCHES_URI} ${SUSPEND2_URI} ${SUSPEND2_URI}"

## END: Exported data

src_unpack() {
	kernel-2_src_unpack
	cd "${S}"
	# manually set extraversion
	sed -i -e "s:^\(EXTRAVERSION =\).*:\1 ${EXTRAVERSION}:" Makefile

}

src_compile() {

	if ! use only_sources; then

		# disable sandbox
		export SANDBOX_ON=0
		export LDFLAGS=""
		export COLLISION_IGNORE="${COLLISION_IGNORE} /lib/firmware"

		# creating workdirs
		mkdir -p ${WORKDIR}/boot/grub
		mkdir ${WORKDIR}/lib
		mkdir ${WORKDIR}/cache
		mkdir ${S}/temp
	
		einfo "Starting to compile kernel..."
		cp ${FILESDIR}/${PF/-r0/}-${ARCH}.config ${WORKDIR}/config || die "cannot copy kernel config"
	
		if use grub; then
			if [ -e "/boot/grub/grub.conf" ]; then
				cp /boot/grub/grub.conf ${WORKDIR}/boot/grub -p
			fi
		fi

		# do some cleanup
		rm -rf "${WORKDIR}"/lib
		rm -rf "${WORKDIR}"/cache
		rm -rf "${S}"/temp
		OLDARCH=${ARCH}
		unset ARCH
		cd ${S}
		GK_ARGS="--disklabel"
		use splash && GKARGS="${GKARGS} --splash=sabayon"
		use dmraid && GKARGS="${GKARGS} --dmraid"
		use grub && GKARGS="${GKARGS} --bootloader=grub"
		export DEFAULT_KERNEL_SOURCE="${S}"
		export CMD_KERNEL_DIR="${S}"
		DEFAULT_KERNEL_SOURCE="${S}" CMD_KERNEL_DIR="${S}" genkernel ${GKARGS} \
			--kerneldir=${S} \
			--kernel-config=${WORKDIR}/config \
			--cachedir=${WORKDIR}/cache \
			--makeopts=-j3 \
			--tempdir=${S}/temp \
			--logfile=${WORKDIR}/genkernel.log \
			--bootdir=${WORKDIR}/boot \
			--mountboot \
			--lvm \
			--luks \
			--disklabel \
			--module-prefix=${WORKDIR}/lib \
			all || die "genkernel failed"
		ARCH=${OLDARCH}

	fi
}

src_install() {

	export COLLISION_IGNORE="${COLLISION_IGNORE} /lib/firmware"

	if ! use no_sources || use only_sources; then
		kernel-2_src_install || die "sources install failed"
		if ! use only_sources; then
			cd ${D}/usr/src/linux-${KV_FULL} || die "cannot cd into sources directory"
			cp Module.symvers Module.symvers.backup -p || die "cannot copy Module.symvers"
			cp System.map System.map.backup -p || die "cannot copy System.map"
			OLDARCH=${ARCH}
			unset ARCH
			make distclean || die "cannot run make distclean"
			cp ${FILESDIR}/${PF/-r0/}-${OLDARCH}.config ${D}/usr/src/linux-${KV_FULL}/.config || die "cannot copy kernel configuration"
			make prepare modules_prepare || die "cannot run make prepare modules_prepare"
			ARCH=${OLDARCH}
			cp Module.symvers.backup Module.symvers -p || die "cannot copy back Module.symvers"
			cp System.map.backup System.map -p || die "cannot copy System.map"
		fi
	fi

	if ! use only_sources; then
		insinto /boot
		doins ${WORKDIR}/boot/*
		cp -Rp ${WORKDIR}/lib/* ${D}/
		rm ${D}/lib/modules/${KV_FULL}/source
		rm ${D}/lib/modules/${KV_FULL}/build
		ln -s /usr/src/linux-${KV_FULL} ${D}/lib/modules/${KV_FULL}/source
		ln -s /usr/src/linux-${KV_FULL} ${D}/lib/modules/${KV_FULL}/build
		if use grub; then
			if [ -e "${WORKDIR}/boot/grub.conf" ]; then
				insinto /boot/grub/
				doins ${WORKDIR}/boot/grub.conf
			fi
		fi
	fi
}

pkg_postinst() {
	kernel-2_pkg_postinst
	einfo "Please report kernel bugs at:"
	einfo "http://bugs.sabayonlinux.org"
}
