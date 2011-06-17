package Gscan2pdf::Tesseract;

use 5.008005;
use strict;
use warnings;
use Carp;
use File::Temp;    # To create temporary files
use File::Basename;

my (%languages);

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
 my ( $class, $file, $language, $tif, $cmd ) = @_;

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
 system($cmd);
 return Gscan2pdf::slurp($txt);
}

system("which tesseract > /dev/null 2> /dev/null") == 0;

__END__
