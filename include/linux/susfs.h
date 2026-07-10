#ifndef KSU_SUSFS_H
#define KSU_SUSFS_H

#include <linux/version.h>
#include <linux/types.h>
#include <linux/utsname.h>
#include <linux/hashtable.h>
#include <linux/path.h>
#include <linux/susfs_def.h>

#define SUSFS_VERSION "v2.2.0"
#if LINUX_VERSION_CODE < KERNEL_VERSION(5,0,0)
#define SUSFS_VARIANT "NON-GKI"
#else
#define SUSFS_VARIANT "GKI"
#endif

/*********/
/* MACRO */
/*********/
#define getname_safe(name) (name == NULL ? ERR_PTR(-EINVAL) : getname(name))
#define putname_safe(name) (IS_ERR(name) ? NULL : putname(name))

/********/
/* ENUM */
/********/
enum UID_SCHEME {
	UID_NON_APP_PROC = 0,
	UID_ROOT_PROC_EXCEPT_SU_PROC,
	UID_NON_SU_PROC,
	UID_UMOUNTED_APP_PROC,
	UID_UMOUNTED_PROC,
};

/**********/
/* STRUCT */
/**********/
/* sus_path */
/* userspace (v2.x NEW layout: no target_ino, kernel resolves it) */
#ifdef CONFIG_KSU_SUSFS_SUS_PATH
struct st_susfs_sus_path {
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	int                              err;
};

/* internal (v1.5.5 hlist, keyed by target_ino; hooks consume this) */
struct st_susfs_sus_path_hlist {
	unsigned long                    target_ino;
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	struct hlist_node                node;
};
#endif

/* sus_mount */
#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT
/* userspace (v2.x: v1.5.5 + trailing int err; matches tool sus_mount_v2000) */
struct st_susfs_sus_mount {
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	unsigned long                    target_dev;
	int                              err;
};

/* internal (v1.5.5 list) */
struct st_susfs_sus_mount_list {
	struct list_head                 list;
	struct st_susfs_sus_mount        info;
};

/* userspace for 0x55561 hide_sus_mnts_for_non_su_procs (inert toggle) */
struct st_susfs_hide_sus_mnts_for_non_su_procs {
	bool                             enabled;
	int                              err;
};
#endif

/* sus_kstat */
#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
#define KSTAT_SPOOF_INO (1 << 0)
#define KSTAT_SPOOF_DEV (1 << 1)
#define KSTAT_SPOOF_NLINK (1 << 2)
#define KSTAT_SPOOF_SIZE (1 << 3)
#define KSTAT_SPOOF_ATIME_TV_SEC (1 << 4)
#define KSTAT_SPOOF_ATIME_TV_NSEC (1 << 5)
#define KSTAT_SPOOF_MTIME_TV_SEC (1 << 6)
#define KSTAT_SPOOF_MTIME_TV_NSEC (1 << 7)
#define KSTAT_SPOOF_CTIME_TV_SEC (1 << 8)
#define KSTAT_SPOOF_CTIME_TV_NSEC (1 << 9)
#define KSTAT_SPOOF_BLOCKS (1 << 10)
#define KSTAT_SPOOF_BLKSIZE (1 << 11)

/* userspace (v2.x v2100: interleaved nsec + flags + err; byte-compatible with tool sus_kstat_v2100) */
struct st_susfs_sus_kstat {
	int                              is_statically;
	unsigned long                    target_ino;
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	unsigned long                    spoofed_ino;
	unsigned long                    spoofed_dev;
	unsigned int                     spoofed_nlink;
	long long                        spoofed_size;
	long                             spoofed_atime_tv_sec;
	unsigned long                    spoofed_atime_tv_nsec;
	long                             spoofed_mtime_tv_sec;
	unsigned long                    spoofed_mtime_tv_nsec;
	long                             spoofed_ctime_tv_sec;
	unsigned long                    spoofed_ctime_tv_nsec;
	long long                        spoofed_blocks;
	long                             spoofed_blksize;
	int                              flags;
	int                              err;
};

/* internal info (v1.5.5 shape: hooks read this field order — DO NOT change) */
struct st_susfs_sus_kstat_info {
	int                              is_statically;
	unsigned long                    target_ino;
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	unsigned long                    spoofed_ino;
	unsigned long                    spoofed_dev;
	unsigned int                     spoofed_nlink;
	long long                        spoofed_size;
	long                             spoofed_atime_tv_sec;
	long                             spoofed_mtime_tv_sec;
	long                             spoofed_ctime_tv_sec;
	long                             spoofed_atime_tv_nsec;
	long                             spoofed_mtime_tv_nsec;
	long                             spoofed_ctime_tv_nsec;
	unsigned long                    spoofed_blksize;
	unsigned long long               spoofed_blocks;
};

/* internal hlist (v1.5.5 shape) */
struct st_susfs_sus_kstat_hlist {
	unsigned long                    target_ino;
	struct st_susfs_sus_kstat_info   info;
	struct hlist_node                node;
};
#endif

/* try_umount */
#ifdef CONFIG_KSU_SUSFS_TRY_UMOUNT
/* userspace (v2.x: v1.5.5 + trailing int err) */
struct st_susfs_try_umount {
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	int                              mnt_mode;
	int                              err;
};

/* internal (v1.5.5 list) */
struct st_susfs_try_umount_list {
	struct list_head                 list;
	struct st_susfs_try_umount       info;
};
#endif

/* spoof_uname */
#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME
struct st_susfs_uname {
	char                             release[__NEW_UTS_LEN+1];
	char                             version[__NEW_UTS_LEN+1];
	int                              err;
};
#endif

/* enable_log */
#ifdef CONFIG_KSU_SUSFS_ENABLE_LOG
struct st_susfs_log {
	bool                             enabled;
	int                              err;
};
#endif

/* spoof_cmdline_or_bootconfig */
#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
struct st_susfs_spoof_cmdline_or_bootconfig {
	char                             fake_cmdline_or_bootconfig[SUSFS_FAKE_CMDLINE_OR_BOOTCONFIG_SIZE];
	int                              err;
};
#endif

/* open_redirect */
#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
/* userspace (v2.x v2100: no target_ino, +uid_scheme +err; kernel resolves ino) */
struct st_susfs_open_redirect {
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	char                             redirected_pathname[SUSFS_MAX_LEN_PATHNAME];
	int                              uid_scheme;
	int                              err;
};

/* internal (v1.5.5 hlist, keyed by target_ino; hooks consume this) */
struct st_susfs_open_redirect_hlist {
	unsigned long                    target_ino;
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	char                             redirected_pathname[SUSFS_MAX_LEN_PATHNAME];
	struct hlist_node                node;
};
#endif

/* sus_map */
#ifdef CONFIG_KSU_SUSFS_SUS_MAP
struct st_susfs_sus_map {
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	int                              err;
};
#endif

/* sus_su */
#ifdef CONFIG_KSU_SUSFS_SUS_SU
struct st_susfs_sus_su {
	int                              mode;
};
#endif

/* enabled features / variant / version (userspace) */
struct st_susfs_enabled_features {
	char                             enabled_features[SUSFS_ENABLED_FEATURES_SIZE];
	int                              err;
};

struct st_susfs_variant {
	char                             susfs_variant[SUSFS_MAX_VARIANT_BUFSIZE];
	int                              err;
};

struct st_susfs_version {
	char                             susfs_version[SUSFS_MAX_VERSION_BUFSIZE];
	int                              err;
};

/***********************/
/* FORWARD DECLARATION */
/***********************/
/* sus_path */
#ifdef CONFIG_KSU_SUSFS_SUS_PATH
void susfs_add_sus_path(void __user **user_info);
int susfs_sus_ino_for_filldir64(unsigned long ino);
#endif
/* sus_mount */
#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT
void susfs_add_sus_mount(void __user **user_info);
void susfs_set_hide_sus_mnts_for_non_su_procs(void __user **user_info);
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
int susfs_auto_add_sus_bind_mount(const char *pathname, struct path *path_target);
#endif // #ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT
void susfs_auto_add_sus_ksu_default_mount(const char __user *to_pathname);
#endif // #ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT
#endif // #ifdef CONFIG_KSU_SUSFS_SUS_MOUNT

/* sus_kstat */
#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
void susfs_add_sus_kstat(void __user **user_info);
void susfs_update_sus_kstat(void __user **user_info);
void susfs_sus_ino_for_generic_fillattr(unsigned long ino, struct kstat *stat);
void susfs_sus_ino_for_show_map_vma(unsigned long ino, dev_t *out_dev, unsigned long *out_ino);
#endif
/* try_umount */
#ifdef CONFIG_KSU_SUSFS_TRY_UMOUNT
void susfs_add_try_umount(void __user **user_info);
void susfs_try_umount(uid_t target_uid);
void susfs_try_umount_all(uid_t uid);
void susfs_run_try_umount_for_current_mnt_ns(void);
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT
void susfs_auto_add_try_umount_for_bind_mount(struct path *path);
#endif // #ifdef CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT
#endif // #ifdef CONFIG_KSU_SUSFS_TRY_UMOUNT
/* spoof_uname */
#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME
void susfs_set_uname(void __user **user_info);
void susfs_spoof_uname(struct new_utsname* tmp);
#endif
/* enable_log */
#ifdef CONFIG_KSU_SUSFS_ENABLE_LOG
void susfs_enable_log(void __user **user_info);
#endif
/* spoof_cmdline_or_bootconfig */
#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
void susfs_set_cmdline_or_bootconfig(void __user **user_info);
int susfs_spoof_cmdline_or_bootconfig(struct seq_file *m);
#endif
/* open_redirect */
#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
void susfs_add_open_redirect(void __user **user_info);
struct filename* susfs_get_redirected_path(unsigned long ino);
#endif
/* sus_map */
#ifdef CONFIG_KSU_SUSFS_SUS_MAP
void susfs_add_sus_map(void __user **user_info);
#endif
/* sus_su */
#ifdef CONFIG_KSU_SUSFS_SUS_SU
int susfs_get_sus_su_working_mode(void);
int susfs_sus_su(struct st_susfs_sus_su* __user user_info);
#endif
/* show / features (outside any sub-feature #ifdef; gated in dispatch) */
void susfs_show_version(void __user **user_info);
void susfs_show_variant(void __user **user_info);
void susfs_get_enabled_features(void __user **user_info);
/* susfs_init */
void susfs_init(void);

#endif