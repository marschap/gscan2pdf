use warnings;
use strict;
use Test::More tests => 4;

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
Gscan2pdf::Frontend::CLI->scanimage(
 device            => 'test',
 npages            => 1,
 new_page_callback => sub {
  my ($path) = @_;
  ok( -e $path, 'basic scan functionality' );
  $loop->quit;
 }
);
$loop->run;

#########################

unlink "out01.pnm";

__END__
