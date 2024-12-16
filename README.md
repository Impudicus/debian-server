# Benutzer verwalten

## Systemnutzer anlegen

``` bash
useradd --shell /bin/false plex
useradd --shell /bin/false porn
```

## Systemnutzer zu Gruppe hinzufügen
``` bash
usermod --append --groups video philipp
```

## Sambanutzer anlegen
``` bash
smbpasswd -a philipp
```


# RAID verwalten

## Raid Array umbenennen
> [!TIP]
>   No data will be lost!

``` bash
umount "/dev/mdx"
mdadm --stop "/dev/mdx"

# cleanup mdadm.conf
# cleanup fstab

mdadm --assemble "/dev/mdx" "/dev/sdx" "/dev/sdy" "/dev/sdz"

mdadm --detail --scan >> "/etc/mdadm/mdadm.conf"

update-initramfs -u
```

## Raid Array in mdadm.conf laden

``` bash
mdadm --detail --scan >> "/etc/mdadm/mdadm.conf"
update-initramfs -u
```

## Raid Array in fstab einbinden

``` bash
echo "$(blkid | grep "md1" | awk '{print $2}')     /mnt/pool1      ext4    defaults                0       2" | tee --append /etc/fstab
echo "$(blkid | grep "md2" | awk '{print $2}')     /mnt/pool2      ext4    defaults                0       3" | tee --append /etc/fstab

systemctl daemon-reload
```

## Raid Array resync beschleunigen

``` bash
sysctl -w dev.raid.speed_limit_min=500000
sysctl -w dev.raid.speed_limit_max=5000000
```

## Raid Array formatieren
> [!CAUTION]
> All data will be lost!

``` bash
mkfs.ext4 "/dev/mdx"
tune2fs -m 0 "/dev/mdx"
```

## Raid Array löschen
> [!CAUTION]
> All data will be lost!

``` bash
umount "/dev/mdx"
mdadm --stop "/dev/mdx"
mdadm --zero-superblock /dev/sd[x-y]

# cleanup mdadm.conf
# cleanup fstab

update-initramfs -u
```
