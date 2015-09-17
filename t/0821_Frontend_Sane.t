use warnings;
use strict;
use Test::More tests => 3;

BEGIN {
    use_ok('Gscan2pdf::Frontend::Sane');
    use Gtk2;
}

#########################

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Sane->setup($logger);

my $path;
Gscan2pdf::Frontend::Sane->open_device(
    device_name       => 'test',
    finished_callback => sub {
        Gscan2pdf::Frontend::Sane->scan_pages(
            dir               => '.',
            npages            => 1,
            new_page_callback => sub {
                ( my $status, $path ) = @_;
                is( $status,  5,     'SANE_STATUS_GOOD' );
                is( -s $path, 30807, 'PNM created with expected size' );
            },
            finished_callback => sub {
                Gtk2->main_quit;
            },
        );
    }
);
Gtk2->main;

#########################

unlink $path;

Gscan2pdf::Frontend::Sane->quit();
