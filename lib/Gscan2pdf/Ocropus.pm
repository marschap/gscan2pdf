package Gscan2pdf::Ocropus;

use 5.008005;
use strict;
use warnings;
use Carp;
use File::Temp;    # To create temporary files
use File::Basename;
use HTML::Entities;
use Encode;
use English qw( -no_match_vars );    # for $PROCESS_ID

our $VERSION = '1.2.5';

my ( $exe, $installed, $setup, $logger );

sub setup {
    ( my $class, $logger ) = @_;
    return $installed if $setup;
    if ( system("which ocroscript > /dev/null 2> /dev/null") == 0 ) {
        my $env = $ENV{OCROSCRIPTS};

        if ( not defined($env) ) {
            for (qw(/usr /usr/local)) {
                if ( -d "$_/share/ocropus/scripts" ) {
                    $env = "$_/share/ocropus/scripts";
                }
            }
        }
        if ( defined $env ) {
            my $script;
            if ( -f "$env/recognize.lua" ) {
                $script = 'recognize';
            }
            elsif ( -f "$env/rec-tess.lua" ) {
                $script = 'rec-tess';
            }
            if ( defined $script ) {
                $exe       = "ocroscript $script";
                $installed = 1;
                $logger->info("Using ocroscript with $script.");
            }
            else {
                $logger->warn(
                    "Found ocroscript, but no recognition scripts. Disabling.");
            }
        }
        else {
            $logger->warn("Found ocroscript, but not its scripts. Disabling.");
        }
    }
    $setup = 1;
    return $installed;
}

sub hocr {
    my ( $class, $file, $language, $loggr, $pidfile ) = @_;
    my ( $png, $cmd );
    if ( not $setup ) { Gscan2pdf::Ocropus->setup($loggr) }

    if ( $file !~ /\.(?:png|jpg|pnm)$/xsm ) {

        # Temporary filename for new file
        $png = File::Temp->new( SUFFIX => '.png' );
        my $image = Image::Magick->new;
        $image->Read($file);
        $image->Write( filename => $png );
    }
    else {
        $png = $file;
    }
    if ($language) {
        $cmd = "tesslanguage=$language $exe $png";
    }
    else {
        $cmd = "$exe $png";
    }
    $logger->info($cmd);

    # decode html->utf8
    my $output;
    if ( defined $pidfile ) {
        ( $output, undef ) =
          Gscan2pdf::Document::open_three("echo $PROCESS_ID > $pidfile;$cmd");
    }
    else {
        ( $output, undef ) = Gscan2pdf::Document::open_three($cmd);
    }
    my $decoded = decode_entities($output);

    # Unfortunately, there seems to be a case (tested in t/31_ocropus_utf8.t)
    # where decode_entities doesn't work cleanly, so encode/decode to finally
    # get good UTF-8
    return decode_utf8( encode_utf8($decoded) );
}

1;

__END__
