use Test::More qw(no_plan);
use File::Spec;
use FindBin;
use lib (
    File::Spec->catfile($FindBin::Bin,"lib"),
    File::Spec->catfile($FindBin::Bin, File::Spec->updir, "lib"),
    );

use Carp;
use IPC::Mutex::Flock;
use IPC::Mutex::ShareLite;
use IPC::ShareLite;

my $global = IPC::ShareLite->new(
    -key     => 'judg',
    -create  => 'yes',
    -destroy => 'yes',
) or die "cannot create IPC::ShareLite: $!";

my $share = IPC::ShareLite->new(
    -key     => 'book',
    -create  => 'yes',
    -destroy => 'yes',
) or die "cannot create IPC::ShareLite: $!";

IPC::Mutex::Flock->new->cleanup;
IPC::Mutex::ShareLite->new->cleanup;

ok(1,"ok");

1;
