use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
    use File::Copy;
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: 1.tif');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

my @files;
for my $i ( 1 .. 10 ) {
    push @files, "$i.tif";
    copy( '1.tif', "$i.tif" ) if ( $i > 1 );
}
$slist->import_files(
    paths             => \@files,
    finished_callback => sub {
        Gtk2->main_quit;
    }
);
Gtk2->main;

is( $#{ $slist->{data} }, 9, 'Imported 10 images' );

#########################

for my $i ( 1 .. 10 ) {
    unlink "$i.tif";
}
unlink <$dir/*>;
Gscan2pdf::Document->quit();
