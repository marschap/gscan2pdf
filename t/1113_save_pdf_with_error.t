use warnings;
use strict;
use Test::More tests => 2;
use Gtk2 -init;    # Could just call init separately

BEGIN {
    use Gscan2pdf::Document;
}

#########################

Glib::set_application_name('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->get_file_info(
    path              => 'test.pnm',
    finished_callback => sub {
        my ($info) = @_;
        $slist->import_file(
            info              => $info,
            first             => 1,
            last              => 1,
            finished_callback => sub {

                # inject error before save_pdf
                chmod 0500, $dir;    # no write access

                $slist->save_pdf(
                    path           => 'test.pdf',
                    list_of_pages  => [ $slist->{data}[0][2] ],
                    error_callback => sub {
                        ok( 1, 'caught error injected before save_pdf' );
                        chmod 0700, $dir;    # allow write access

                        $slist->save_pdf(
                            path            => 'test.pdf',
                            list_of_pages   => [ $slist->{data}[0][2] ],
                            queued_callback => sub {

                                # inject error during save_pdf
                                chmod 0500, $dir;    # no write access
                            },
                            error_callback => sub {
                                ok( 1,
                                    'save_pdf caught error injected in queue' );
                                chmod 0700, $dir;    # allow write access
                                Gtk2->main_quit;
                            }
                        );

                    }
                );
            }
        );
    }
);
Gtk2->main;

#########################

unlink 'test.pnm', 'test.pdf';
Gscan2pdf::Document->quit();
