use warnings;
use strict;
use Image::Sane ':all';    # To get SANE_* enums
use Test::More tests => 48;

BEGIN {
    use_ok('Gscan2pdf::Frontend::CLI');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::CLI->setup($logger);

#########################

my $brx = SANE_NAME_SCAN_BR_X;
my $bry = SANE_NAME_SCAN_BR_Y;

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

is(
    Gscan2pdf::Frontend::CLI::_create_scanimage_cmd(
        {
            device  => 'test',
            prefix  => '',
            options => Gscan2pdf::Scanner::Profile->new_from_data(
                { backend => [ { $brx => 10 } ] }
            )->map_to_cli
        }
    ),
    " scanimage --help --device-name='test' -x 10",
    "map Sane geometry options back to scanimage options"
);

#########################

is(
    Gscan2pdf::Frontend::CLI::_create_scanimage_cmd(
        {
            device  => 'test',
            prefix  => '',
            options => Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend =>
                      [ { $brx => 10 }, { $bry => 10 }, { mode => 'Color' } ]
                }
            )->map_to_cli
        }
    ),
    " scanimage --help --device-name='test' -x 10 -y 10 --mode='Color'",
    "map more Sane geometry options"
);

#########################

is(
    Gscan2pdf::Frontend::CLI::_create_scanimage_cmd(
        {
            device  => 'test',
            prefix  => '',
            options => Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend =>
                      [ { $brx => 10 }, { $bry => 10 }, { button => undef } ]
                }
            )->map_to_cli
        }
    ),
    " scanimage --help --device-name='test' -x 10 -y 10 --button",
    "map button option"
);

#########################

my $running  = 0;
my $new_page = 0;
my $error    = 0;
my %options  = (
    frontend          => 'scanimage',
    num_scans         => 0,
    running_callback  => sub { $running++ },
    new_page_callback => sub { $new_page++ },
    error_callback    => sub { $error++ }
);

# error strings from scanimage 1.0.25
for my $msg (
    (
        sprintf( "%s: received signal %d",     $options{frontend}, 13 ),
        sprintf( "%s: trying to stop scanner", $options{frontend} ),
        sprintf( "%s: aborting",               $options{frontend} )
    )
  )
{
    Gscan2pdf::Frontend::CLI::cancel_scan();
    Gscan2pdf::Frontend::CLI::parse_scanimage_output( $msg, \%options );
    is( $error, 0, "$msg with cancel" );
    $error = 0;
}

for my $msg (
    (
        sprintf(
            "%s: sane_start: %s",
            $options{frontend}, 'Document feeder out of documents'
        ),
        sprintf( "%s: received signal %d",     $options{frontend}, 13 ),
        sprintf( "%s: trying to stop scanner", $options{frontend} ),
        sprintf( "%s: aborting",               $options{frontend} )
    )
  )
{
    Gscan2pdf::Frontend::CLI::uncancel_scan();
    Gscan2pdf::Frontend::CLI::parse_scanimage_output( $msg, \%options );
    is( $error, 1, "$msg without cancel" );
    $error = 0;
}

# progress strings from scanimage 1.0.25
for my $msg (
    (
        sprintf( "Progress: %3.1f%%", 81.3 ),
        sprintf(
            "Scanning %d pages, incrementing by %d, numbering from %d",
            -1, 1, 1
        ),
        sprintf( "Scanning page %d", 1 )
    )
  )
{
    Gscan2pdf::Frontend::CLI::parse_scanimage_output( $msg, \%options );
    is( $running, 1, $msg );
    $running = 0;
}

# new page strings from scanimage 1.0.25
# loop required due to Glib::Timeout
my $loop = Glib::MainLoop->new;
$options{new_page_callback} = sub {
    $new_page++;
    $loop->quit;
};
my $msg = sprintf "Scanned page %d. (scanner status = %d)", 1, SANE_STATUS_EOF;
system 'touch out1.pnm';
Gscan2pdf::Frontend::CLI::parse_scanimage_output( $msg, \%options );
$loop->run;
unlink 'out1.pnm';
is( $new_page, 1, $msg );
$new_page = 0;

# ignored strings from scanimage 1.0.25
for my $msg (
    (
        sprintf(
            "%s: rounded value of %s from %d to %d",
            $options{frontend}, 'xxx', 11, 11
        ),
        sprintf(
            "%s: sane_start: %s",
            $options{frontend}, 'Document feeder out of documents'
        ),
    )
  )
{
    Gscan2pdf::Frontend::CLI::parse_scanimage_output( $msg, \%options );
    is( $running + $new_page + $error, 0, $msg );
    $error = 0;
}

#########################

# ignored strings from scanimage 1.0.27
for my $msg ( ( sprintf( "Batch terminated, %d pages scanned", 2 ), ) ) {
    Gscan2pdf::Frontend::CLI::parse_scanimage_output( $msg, \%options );
    is( $running + $new_page + $error, 0, $msg );
    $error = 0;
}

# progress strings from scanimage 1.0.27
for my $msg (
    (
        sprintf(
            "Scanning %d page, incrementing by %d, numbering from %d",
            1, 1, 1
        ),
        sprintf(
            "Scanning %s pages, incrementing by %d, numbering from %d",
            'infinity', 1, 1
        ),
    )
  )
{
    Gscan2pdf::Frontend::CLI::parse_scanimage_output( $msg, \%options );
    is( $running, 1, $msg );
    $running = 0;
}

#########################

$loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI::_watch_cmd(
    cmd              => 'echo hello stdout',
    started_callback => sub {
        pass('started watching only stdout');
    },
    out_callback => sub {
        my ($output) = @_;
        is( $output, "hello stdout\n", 'stdout watching only stdout' );
    },
    finished_callback => sub {
        my ( $output, $error ) = @_;
        is( $output, "hello stdout\n", 'stdout finished watching only stdout' );
        is( $error,  undef,            'stderr finished watching only stdout' );
        $loop->quit;
    }
);
$loop->run;

#########################

$loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI::_watch_cmd(
    cmd              => 'echo hello stderr 1>&2',
    started_callback => sub {
        pass('started watching only stderr');
    },
    err_callback => sub {
        my ($output) = @_;
        is( $output, "hello stderr\n", 'stderr watching only stderr' );
    },
    finished_callback => sub {
        my ( $output, $error ) = @_;
        is( $output, undef,            'stdout finished watching only stderr' );
        is( $error,  "hello stderr\n", 'stderr finished watching only stderr' );
        $loop->quit;
    }
);
$loop->run;

#########################

$loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI::_watch_cmd(
    cmd              => 'echo hello stdout; echo hello stderr 1>&2',
    started_callback => sub {
        pass('started watching stdout and stderr');
    },
    out_callback => sub {
        my ($output) = @_;
        is( $output, "hello stdout\n", 'stdout watching stdout and stderr' );
    },
    err_callback => sub {
        my ($output) = @_;
        is( $output, "hello stderr\n", 'stderr watching stdout and stderr' );
    },
    finished_callback => sub {
        my ( $output, $error ) = @_;
        is(
            $output,
            "hello stdout\n",
            'stdout finished watching stdout and stderr'
        );
        is(
            $error,
            "hello stderr\n",
            'stderr finished watching stdout and stderr'
        );
        $loop->quit;
    }
);
$loop->run;

#########################

$loop = Glib::MainLoop->new;
my $cmd = 'cat scanners/*';
Gscan2pdf::Frontend::CLI::_watch_cmd(
    cmd              => $cmd,
    started_callback => sub {
        pass('started watching large amounts of stdout');
    },
    finished_callback => sub {
        my ( $output, $error ) = @_;
        is( length($output) . "\n",
            `$cmd | wc -c`,
            'stdout finished watching large amounts of stdout' );
        is( $error, undef, 'stderr finished watching large amounts of stdout' );
        $loop->quit;
    }
);
$loop->run;

#########################

$loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI->find_scan_options(
    device            => 'test',
    finished_callback => sub {
        my ($options) = @_;
        is( $options->by_name('source')->{name}, 'source', 'by_name' );
        is( $options->by_name('button')->{name}, 'button', 'by_name' );
        is( $options->by_name('mode')->{val},
            'Gray', 'find_scan_options default option' );
        $loop->quit;
    }
);
$loop->run;

#########################

$loop = Glib::MainLoop->new;
Gscan2pdf::Frontend::CLI->find_scan_options(
    device  => 'test',
    options => Gscan2pdf::Scanner::Profile->new_from_data(
        { backend => [ { mode => 'Color' } ] }
    ),
    finished_callback => sub {
        my ($options) = @_;
        is( $options->by_name('mode')->{val},
            'Color', 'find_scan_options with option' );
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
        pass('scanimage starts');
    },
    new_page_callback => sub {
        my ( $path, $n ) = @_;
        ok( -e $path, 'scanimage scans' );
        unlink $path;
    },
    finished_callback => sub {
        pass('scanimage finishes');
        $loop->quit;
    },
    error_callback => sub {
        my ($msg) = @_;
        fail "error callback called: $msg";
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
        pass('scanadf starts');
    },
    new_page_callback => sub {
        my ( $path, $n ) = @_;
        ok( -e $path, 'scanadf scans' );
        unlink $path;
    },
    finished_callback => sub {
        pass('scanadf finishes');
        $loop->quit;
    },
);
$loop->run;

#########################

__END__
