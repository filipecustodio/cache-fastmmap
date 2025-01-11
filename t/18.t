
#########################

use Test::More;

BEGIN {
  if ($^O eq "MSWin32") {
    plan skip_all => 'No FD_CLOEXEC tests, running on Windows';
  }
  if (!-d "/proc/$$") {
    plan skip_all => 'No FD_CLOEXEC tests, no /proc filesystem';
  }
}


use strict;
use Fcntl;

#########################

# Test fd's are closed on exec

if (@ARGV) {
  my $PipeFd = shift @ARGV;
  my $FdCount = scalar(() = glob "/proc/$$/fd/*");
  open(my $PipeFh, ">&=$PipeFd")
    || die "Could not reopen fd: $!";
  print($PipeFh "$FdCount\n")
    || die "Could not print to pipe: $!";
  exit(0);
}

# Count the "native" fd descriptors openned before Cache::FastMmap
my $native_fd = scalar(() = glob "/proc/$$/fd/*");

require Cache::FastMmap;
my @Caches = map {
  Cache::FastMmap->new(
    page_size => 4096,
    num_pages => 1,
    init_file => 1,
    serializer => '',
  );
} (1 .. 20);
my $CacheCount = @Caches;

my $FdCount = scalar(() = glob "/proc/$$/fd/*") - $native_fd;
ok($FdCount >= $CacheCount, "More fd's than caches: $FdCount < $CacheCount");

pipe(my $ReadPipeFh, my $WritePipeFh)
  || die "pipe failed: $!";

fcntl($ReadPipeFh, F_SETFD, 0);
fcntl($WritePipeFh, F_SETFD, 0);

if (!fork) {
  exec $^X, $0, fileno($WritePipeFh)
    || die "exec failed: $!";
}

my $ChildFdCount = <$ReadPipeFh>;
chomp $ChildFdCount;
$ChildFdCount -= $native_fd;
ok($ChildFdCount <= $CacheCount, "Less fd's in child than caches: $ChildFdCount > $CacheCount");

done_testing(2);

