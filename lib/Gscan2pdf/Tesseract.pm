package Gscan2pdf::Tesseract;

use 5.008005;
use strict;
use warnings;
use Carp;
use File::Temp;    # To create temporary files
use File::Basename;
use Gscan2pdf;     # for slurp

my ( %languages, $installed, $setup, $version, $tessdata, $suffix );

sub setup {
 return $installed if $setup;
 $installed = 1 if ( system("which tesseract > /dev/null 2> /dev/null") == 0 );
 $tessdata = `tesseract '' '' -l '' 2>&1`;
 chomp $tessdata;
 if ( $tessdata =~ s/^Unable to load unicharset file // ) {
  $version = 2;
  $suffix  = '.unicharset';
 }
 elsif ( $tessdata =~ s/^Error openn?ing data file // ) {
  $version = 3;
  $suffix  = '.traineddata';
 }
 $tessdata =~ s/\/$suffix$//;
 $main::logger->info(
  "Found tesseract version $version. Using tessdata at $tessdata");
 $setup = 1;
 return $installed;
}

sub languages {
 unless (%languages) {
  my %iso639 = (
   deu        => 'German',
   'deu-f'    => 'German (Fraktur)',
   'deu-frak' => 'German (Fraktur)',
   eng        => 'English',
   fra        => 'French',
   ita        => 'Italian',
   nld        => 'Dutch',
   por        => 'Portuguese',
   slk        => 'Slovak',
   spa        => 'Spanish',
   vie        => 'Vietnamese',
  );
  for ( glob "$tessdata/*$suffix" ) {

   # Weed out the empty language files
   if ( not -z $_ ) {
    my $code;
    $code = $1 if ( $_ =~ /([\w\-]*)$suffix$/ );
    $main::logger->info("Found tesseract language $code");
    if ( defined $iso639{$code} ) {
     $languages{$code} = $iso639{$code};
    }
    else {
     $languages{$code} = $code;
    }
   }
  }
 }
 return \%languages;
}

sub hocr {
 my ( $class, $file, $language, $pidfile, $tif, $cmd ) = @_;
 setup() unless $setup;

 # Temporary filename for output
 my $suffix = $version == 3 ? '.html' : '.txt';
 my $txt = File::Temp->new( SUFFIX => $suffix );
 ( my $name, my $path, $suffix ) = fileparse( $txt, $suffix );

 if ( $file !~ /\.tif$/ ) {

  # Temporary filename for new file
  $tif = File::Temp->new( SUFFIX => '.tif' );
  my $image = Image::Magick->new;
  $image->Read($file);
  $image->Write( filename => $tif );
 }
 else {
  $tif = $file;
 }
 if ( $version == 3 ) {
  $cmd =
"echo tessedit_create_hocr 1 > hocr.config;tesseract $tif $path$name -l $language +hocr.config 2> /dev/null;rm hocr.config";
 }
 elsif ($language) {
  $cmd = "tesseract $tif $path$name -l $language 2> /dev/null";
 }
 else {
  $cmd = "tesseract $tif $path$name 2> /dev/null";
 }
 $main::logger->info($cmd);
 if ( defined $pidfile ) {
  system("echo $$ > $pidfile;$cmd");
 }
 else {
  system($cmd);
 }
 return Gscan2pdf::slurp($txt);
}

1;

__END__
