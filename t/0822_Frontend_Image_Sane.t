use warnings;
use strict;
use Gscan2pdf::Scanner::Options;
use Test::More tests => 3;

BEGIN {
    use_ok('Gscan2pdf::Frontend::Image_Sane');
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Image_Sane->setup($logger);

#########################

my $loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::Image_Sane->open_device(
    device_name       => 'test',
    finished_callback => sub {
        ok 1, 'opened device';
        Gscan2pdf::Frontend::Image_Sane->find_scan_options(
            undef, undef,
            sub {    # finished callback
                my ($data)  = @_;
                my $options = Gscan2pdf::Scanner::Options->new_from_data($data);
                my $option  = $options->by_name('enable-test-options');
                Gscan2pdf::Frontend::Image_Sane->set_option(
                    index             => $option->{index},
                    value             => '',
                    finished_callback => sub {
                        my ($data) = @_;
                        if ($data) {
                            $options =
                              Gscan2pdf::Scanner::Options->new_from_data($data);
                        }
                        is( $options->by_name('enable-test-options')->{val},
                            0, 'bool false as empty string' );
                        $loop->quit;
                    }
                );
            }
        );
    }
);
$loop->run;

#########################

Gscan2pdf::Frontend::Image_Sane->quit;

__END__
