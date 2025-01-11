#!/bin/sh

# copied together from initramfs-tools

set -eu

# Read bytes out of a file, checking that they are valid hex digits
readhex()
{
	dd < "$1" bs=1 skip="$2" count="$3" 2> /dev/null | \
		LANG=C grep -E "^[0-9A-Fa-f]{$3}\$"
}

# Check for a zero byte in a file
checkzero()
{
	dd < "$1" bs=1 skip="$2" count=1 2> /dev/null | \
		LANG=C grep -q -z '^$'
}

initramfs="$1"
overlay="${2:-}"

start=0
while true; do
	end=$start
	while true; do
		if checkzero "$initramfs" $end; then
			end=$((end + 4))
			while checkzero "$initramfs" $end; do
				end=$((end + 4))
			done
			break
		fi
		magic="$(readhex "$initramfs" $end 6)" || break
		test "$magic" = 070701 || test "$magic" = 070702 || break
		namesize=0x$(readhex "$initramfs" $((end + 94)) 8)
		filesize=0x$(readhex "$initramfs" $((end + 54)) 8)
		end=$(((end + 110)))
		end=$(((end + namesize + 3) & ~3))
		end=$(((end + filesize + 3) & ~3))
	done
	if [ $end -eq $start ]; then
		break
	fi
	echo "skipping early segment at $start, size=$((end - start))"
	start=$end
done

echo "main segment starting from $end"

# copy main segment into temp file

mainseg="$(mktemp)"
trap 'rm -f "$mainseg"' EXIT
dd < "$initramfs" skip=$end iflag=skip_bytes 2> /dev/null > "$mainseg"

# uncpio main segment into temp dir

maindir="$(mktemp -d)"
(
	cd "$maindir";
	zstd -q -c -d "$mainseg" |
		cpio --quiet -i --preserve-modification-time --no-absolute-filenames
)

# copy overlay dir over extracted main segment

cp -TRv "$overlay" "$maindir"

# re-cpio new main segment into temp file

newseg="$(mktemp)"
trap 'rm -f "$newseg"' EXIT
(
	cd "$maindir";
	find . | LC_ALL=C sort | cpio -o --format=newc |
		zstd -q -1 -c > "$newseg"
)

# dd new cpio over original main segment

truncate -s $end "$initramfs"
cat "$newseg" >> "$initramfs"
