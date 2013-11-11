use warnings;
use strict;
use Storable qw(store retrieve);
use Test::More tests => 1;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

my $sessionref = retrieve( File::Spec->catfile( 'tmp', 'session' ) );
unlink "$sessionref->{1}{filename}";

Gscan2pdf::Document->setup(Log::Log4perl::get_logger);
my $slist = Gscan2pdf::Document->new;
$slist->open_session(
 'tmp', undef,
 sub {
  my ($msg) = @_;
  is(
   $msg,
   'Error importing page 1. Ignoring.',
   'trap error on opening non-existent file'
  );
 }
);

#########################

unlink <tmp/*>;
rmdir 'tmp';
Gscan2pdf::Document->quit;
