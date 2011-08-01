package Gscan2pdf::Tesseract;

use 5.008005;
use strict;
use warnings;
use Carp;
use File::Temp;    # To create temporary files
use File::Basename;
use Gscan2pdf;     # for slurp

my ( %languages, $installed, $setup );

sub setup {
 return $installed if $setup;
 $installed = 1 if ( system("which tesseract > /dev/null 2> /dev/null") == 0 );
 $setup = 1;
 return $installed;
}

sub languages {
 unless (%languages) {
  my $tessdata = `tesseract '' '' -l '' 2>&1`;
  chomp $tessdata;
  $tessdata =~ s/^Unable to load unicharset file //;
  $tessdata =~ s/\/\.unicharset$//;
  $main::logger->info("Using tessdata at $tessdata");
  my %iso639 = (
   deu     => 'German',
   'deu-f' => 'German (Fraktur)',
   eng     => 'English',
   fra     => 'French',
   ita     => 'Italian',
   nld     => 'Dutch',
   por     => 'Portuguese',
   slk     => 'Slovak',
   spa     => 'Spanish',
   vie     => 'Vietnamese',
  );
  for ( glob "$tessdata/*.unicharset" ) {

   # Weed out the empty language files
   if ( not -z $_ ) {
    my $code;
    $code = $1 if ( $_ =~ /([\w\-]*)\.unicharset$/ );
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

sub text {
 my ( $class, $file, $language, $pidfile, $tif, $cmd ) = @_;
 setup() unless $setup;

 # Temporary filename for output
 my $txt = File::Temp->new( SUFFIX => '.txt' );
 my ( $name, $path, $suffix ) = fileparse( $txt, ".txt" );

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
 if ($language) {
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
