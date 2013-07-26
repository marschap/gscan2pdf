use warnings;
use strict;
use Test::More tests => 6;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately

BEGIN {
 use_ok('Gscan2pdf::Dialog::Scan::CLI');
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::CLI->setup($logger);

ok(
 my $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
  title           => 'title',
  'transient-for' => $window,
  'logger'        => $logger,
 ),
 'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan::CLI' );

is( $dialog->get('cache-options'), 0, 'default cache-options' );

my $signal;
$signal = $dialog->signal_connect(
 'changed-cache-options' => sub {
  my ( $widget, $cache_options ) = @_;
  $dialog->signal_handler_disconnect($signal);
  is( $cache_options, TRUE, 'changed cache-options' );
 }
);
$dialog->set( 'cache-options', TRUE );

$signal = $dialog->signal_connect(
 'changed-options-cache' => sub {
  my ( $widget, $cache ) = @_;
  $dialog->signal_handler_disconnect($signal);
  ok( 1, 'changed options-cache' );
  Gtk2->main_quit;
 }
);
$dialog->set( 'device-list', [ { 'name' => 'test' } ] );
$dialog->set( 'device', 'test' );

Gtk2->main;

__END__
