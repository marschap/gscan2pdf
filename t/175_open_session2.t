use warnings;
use strict;
use Test::More tests => 2;
use File::Basename;    # Split filename into dir, file, ext

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

my $slist = Gscan2pdf::Document->new;
$slist->set_dir( File::Temp->newdir );
$slist->open_session_file( info => 't/1.gs2p' );
use Data::Dumper;
my $string = Dumper( $slist->{data} );

SKIP: {
    skip 'file-5.31 cannot detect PGM', 1
      if `file --version` =~ /file-5\.31$/m;
    like(
         `file $slist->{data}[0][2]{filename}`,
         qr/image data/,
         'extracted valid image'
        );
}

#########################

$slist = Gscan2pdf::Document->new;
$slist->set_dir( File::Temp->newdir );
$slist->open_session_file(
    info              => 't/1.gs2p',
    finished_callback => sub {
        pass('in finished_callback');
    }
);

#########################

Gscan2pdf::Document->quit();
unlink 'test.pnm';
