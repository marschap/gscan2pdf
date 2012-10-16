use warnings;
use strict;
use Test::More tests => 19;

BEGIN {
 use_ok('Gscan2pdf::Frontend::CLI');
}

#########################

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::CLI->setup($logger);

#########################

my $output = <<'END';
'0','test:0','Noname','frontend-tester','virtual device'
'1','test:1','Noname','frontend-tester','virtual device'
END

is_deeply(
 Gscan2pdf::Frontend::CLI->parse_device_list($output),
 [
  {
   'name'   => 'test:0',
   'model'  => 'frontend-tester',
   'type'   => 'virtual device',
   'vendor' => 'Noname'
  },
  {
   'name'   => 'test:1',
   'model'  => 'frontend-tester',
   'type'   => 'virtual device',
   'vendor' => 'Noname'
  }
 ],
 "basic parse_device_list functionality"
);

#########################

is_deeply( Gscan2pdf::Frontend::CLI->parse_device_list(''),
 [], "parse_device_list no devices" );

#########################

my $loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI::_watch_cmd(
 'echo hello stdout',
 sub {
  ok( 1, 'started watching only stdout' );
 },
 sub {
  my ($output) = @_;
  is( $output, "hello stdout\n", 'stdout watching only stdout' );
 },
 undef,
 sub {
  ok( 1, 'finished watching only stdout' );
  $loop->quit;
 }
);
$loop->run;

#########################

$loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI::_watch_cmd(
 'echo hello stderr 1>&2',
 sub {
  ok( 1, 'started watching only stderr' );
 },
 undef,
 sub {
  my ($output) = @_;
  is( $output, "hello stderr\n", 'stderr watching only stderr' );
 },
 sub {
  ok( 1, 'finished watching only stderr' );
  $loop->quit;
 }
);
$loop->run;

#########################

$loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI::_watch_cmd(
 'echo hello stdout; echo hello stderr 1>&2',
 sub {
  ok( 1, 'started watching stdout and stderr' );
 },
 sub {
  my ($output) = @_;
  is( $output, "hello stdout\n", 'stdout watching stdout and stderr' );
 },
 sub {
  my ($output) = @_;
  is( $output, "hello stderr\n", 'stderr watching stdout and stderr' );
 },
 sub {
  ok( 1, 'finished watching stdout and stderr' );
  $loop->quit;
 }
);
$loop->run;

#########################

$loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI->scan_pages(
 frontend         => 'scanimage',
 device           => 'test',
 npages           => 1,
 started_callback => sub {
  ok( 1, 'scanimage starts' );
 },
 new_page_callback => sub {
  my ($path) = @_;
  ok( -e $path, 'scanimage scans' );
  unlink $path;
  $loop->quit;
 },
 finished_callback => sub {
  ok( 1, 'scanimage finishes' );
 },
);
$loop->run;

#########################

$loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI->scan_pages(
 frontend         => 'scanadf',
 device           => 'test',
 npages           => 1,
 started_callback => sub {
  ok( 1, 'scanadf starts' );
 },
 new_page_callback => sub {
  my ($path) = @_;
  ok( -e $path, 'scanadf scans' );
  unlink $path;
  $loop->quit;
 },
 finished_callback => sub {
  ok( 1, 'scanadf finishes' );
 },
);
$loop->run;

#########################

__END__
