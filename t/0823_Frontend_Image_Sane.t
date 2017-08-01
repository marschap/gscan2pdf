use warnings;
use strict;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2;
use Gscan2pdf::Frontend::Image_Sane;
use Gscan2pdf::Scanner::Options;
use Test::More tests => 3;

#########################

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $path;
Gscan2pdf::Frontend::Image_Sane->open_device(
    device_name       => 'test',
    finished_callback => sub {
        Gscan2pdf::Frontend::Image_Sane->find_scan_options(
            undef, undef,
            sub {    # finished callback
                my ($data)  = @_;
                my $options = Gscan2pdf::Scanner::Options->new_from_data($data);
                my $option  = $options->by_name('hand-scanner');
                Gscan2pdf::Frontend::Image_Sane->set_option(
                    index             => $option->{index},
                    value             => TRUE,
                    finished_callback => sub {
                        Gscan2pdf::Frontend::Image_Sane->scan_pages(
                            dir               => '.',
                            npages            => 1,
                            new_page_callback => sub {
                                ( my $status, $path ) = @_;
                                is( $status, 5, 'SANE_STATUS_GOOD' );
                              SKIP: {
                                    skip 'file-5.31 cannot detect PGM', 1
                                      if `file --version` =~ /file-5\.31$/m;
                                    like(
                                        `file $path`,
                                        qr/Netpbm /,
                                        'Output has valid header'
                                    );
                                }
                                like(
                                    `identify $path`,
qr/PGM 216x334 216x334\+0\+0 8-bit Grayscale Gray/,
                                    'Output is valid image'
                                );
                            },
                            finished_callback => sub {
                                Gtk2->main_quit;
                            },
                        );
                    }
                );
            }
        );
    }
);
Gtk2->main;

#########################

unlink $path;

Gscan2pdf::Frontend::Image_Sane->quit();
