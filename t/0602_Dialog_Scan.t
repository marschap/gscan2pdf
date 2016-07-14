use warnings;
use strict;
use Test::More tests => 11;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Sane 0.05;              # To get SANE_* enums

BEGIN {
    use Gscan2pdf::Dialog::Scan::Sane;
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->set(
    'paper-formats',
    {
        new => {
            l => 0,
            y => 10,
            x => 10,
            t => 0,
        }
    }
);

$dialog->set( 'num-pages', 2 );

my $profile_changes = 0;
my $signal;
$signal = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect($signal);

        my $options = $dialog->get('available-scan-options');

        # v1.3.7 had the bug that profiles were not being saved properly,
        # due to the profiles not being cloned in the set and get routines
        $dialog->set_option( $options->by_name('tl-x'), 10 );
        $dialog->set_option( $options->by_name('tl-y'), 10 );
        $dialog->save_current_profile('profile 1');
        is_deeply(
            $dialog->{profiles},
            {
                'profile 1' => {
                    backend => [
                        {
                            'tl-x' => '10'
                        },
                        {
                            'tl-y' => '10'
                        },
                    ]
                }
            },
            'applied 1st profile'
        );
        $dialog->set_option( $options->by_name('tl-x'), 20 );
        $dialog->set_option( $options->by_name('tl-y'), 20 );
        $dialog->save_current_profile('profile 2');
        is_deeply(
            $dialog->{profiles},
            {
                'profile 1' => {
                    backend => [
                        {
                            'tl-x' => '10'
                        },
                        {
                            'tl-y' => '10'
                        },
                    ]
                },
                'profile 2' => {
                    backend => [
                        {
                            'tl-x' => '20'
                        },
                        {
                            'tl-y' => '20'
                        },
                    ]
                },
            },
            'applied 2nd profile without affecting 1st'
        );

        $dialog->remove_profile('profile 1');
        is_deeply(
            $dialog->{profiles},
            {
                'profile 2' => {
                    backend => [
                        {
                            'tl-x' => '20'
                        },
                        {
                            'tl-y' => '20'
                        },
                    ]
                },
            },
            'remove_profile()'
        );

        is $options->by_name('source')->{val}, 'Flatbed',
          'source defaults to Flatbed';
        is $dialog->get('num-pages'), 1,
          'allow-batch-flatbed should force num-pages';
        is $dialog->{framen}->is_sensitive, FALSE, 'num-page gui ghosted';
        $dialog->set( 'num-pages', 2 );
        is $dialog->get('num-pages'), 1,
          'allow-batch-flatbed should force num-pages2';

        $dialog->set( 'allow-batch-flatbed', TRUE );
        $dialog->set( 'num-pages',           2 );
        $signal = $dialog->signal_connect(
            'changed-num-pages' => sub {
                $dialog->signal_handler_disconnect($signal);
                is $dialog->get('num-pages'), 1,
                  'allow-batch-flatbed should force num-pages3';
                is $dialog->{framen}->is_sensitive, FALSE,
                  'num-page gui ghosted2';
                Gtk2->main_quit;
            }
        );
        $dialog->set( 'allow-batch-flatbed', FALSE );
    }
);
$dialog->set( 'device', 'test' );
$dialog->scan_options;
Gtk2->main;

is( Gscan2pdf::Dialog::Scan::get_combobox_num_rows( $dialog->{combobp} ),
    3, 'available paper reapplied after setting/changing device' );
is( $dialog->{combobp}->get_active_text,
    'Manual', 'paper combobox has a value' );

Gscan2pdf::Frontend::Sane->quit;
__END__
