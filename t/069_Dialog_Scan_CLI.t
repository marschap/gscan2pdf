use warnings;
use strict;
use Test::More tests => 4;
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
  title             => 'title',
  'transient-for'   => $window,
  'logger'          => $logger,
  'reload-triggers' => qw(mode),
 ),
 'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan::CLI' );

$dialog->set( 'cache-options', TRUE );

$dialog->signal_connect(
 'process-error' => sub {
  my ( $widget, $process, $msg ) = @_;
  Gtk2->main_quit;
 }
);

my ( $signal, $signal2 );
$signal = $dialog->signal_connect(
 'reloaded-scan-options' => sub {
  $dialog->signal_handler_disconnect($signal);

  $signal = $dialog->signal_connect(
   'changed-options-cache' => sub {
    my ( $widget, $cache ) = @_;
    $dialog->signal_handler_disconnect($signal);
    my @keys = keys( %{ $cache->{test} } );
    is_deeply(
     \@keys,
     [ 'mode,Color', 'mode,Gray', 'default' ],
     'starting with a non-default profile'
    );
    Gtk2->main_quit;
   }
  );
  $dialog->set_option( $dialog->get('available-scan-options')->by_name('mode'),
   'Color' );
 }
);
$dialog->set( 'device-list', [ { 'name' => 'test' } ] );
$dialog->set( 'device', 'test' );

Gtk2->main;

#########################

__END__
