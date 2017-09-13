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

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::CLI->setup($logger);

my $cache = {
    'test' => {
        'default' => []
    }
};

ok(
    my $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
        title             => 'title',
        'transient-for'   => $window,
        'logger'          => $logger,
        'reload-triggers' => qw(mode),
        'cache-options'   => TRUE,
        'options-cache'   => $cache,
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan::CLI' );

$dialog->signal_connect(
    'process-error' => sub {
        my ( $widget, $process, $msg ) = @_;
        Gtk2->main_quit;
    }
);

my ($signal);
my $flag = FALSE;
$signal = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect($signal);

        isnt( $dialog->get('available-scan-options')->num_options,
            0, 'starting with an empty cache should force a real reload' );
        if ($flag) { Gtk2->main_quit }
        $flag = TRUE;
    }
);
$dialog->set( 'device-list', [ { 'name' => 'test' } ] );
$dialog->set( 'device', 'test' );

if ( not $flag ) {
    $flag = TRUE;
    Gtk2->main;
}

#########################

__END__
