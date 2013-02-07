package Gscan2pdf::Tesseract;

use 5.008005;
use strict;
use warnings;
use Carp;
use File::Temp;    # To create temporary files
use File::Basename;
use Gscan2pdf::Document;    # for slurp
use version;

my ( %languages, $installed, $setup, $version, $tessdata, $datasuffix,
 $logger );

sub setup {
 ( my $class, $logger ) = @_;
 return $installed if $setup;

 my ( $exe, undef ) = Gscan2pdf::Document::open_three('which tesseract');
 return if ( not defined($exe) or $exe eq '' );
 $installed = 1;

# if we have 3.02.01 or better, we can use --list-langs and not bother with tessdata
 my ( $out, $err ) = Gscan2pdf::Document::open_three("tesseract -v");
 if ( $err =~ /^tesseract\ ([\d\.]+)/x ) {
  $version = $1;
 }
 if ( $version and version->parse("v$version") > version->parse('v3.02') ) {
  $logger->info("Found tesseract version $version.");
  $setup = 1;
  return $installed;
 }

 ( $out, $err ) = Gscan2pdf::Document::open_three("tesseract '' '' -l ''");
 ( $tessdata, $version, $datasuffix ) = parse_tessdata( $out . $err );

 unless ( defined $tessdata ) {
  if ( $version and version->parse("v$version") > version->parse('v3.01') ) {
   my ( $lib, undef ) = Gscan2pdf::Document::open_three("ldd $exe");
   if ( $lib =~ /libtesseract\.so.\d+\ =>\ ([\/a-zA-Z0-9\-\.\_]+)\ /x ) {
    ( $out, undef ) = Gscan2pdf::Document::open_three("strings $1");
    $tessdata = parse_strings($out);
   }
   else {
    return;
   }
  }
  else {
   return;
  }
 }

 $logger->info("Found tesseract version $version. Using tessdata at $tessdata");
 $setup = 1;
 return $installed;
}

sub parse_tessdata {
 my @output = @_;
 my $output = join ",", @output;
 my ( $v, $suffix );
 if ( $output =~ /\ v(\d\.\d\d)\ /x ) {
  $v = $1 + 0;
 }
 if ( $output =~ /Unable\ to\ load\ unicharset\ file\ (.+)/x ) {
  $output = $1;
  $v      = 2 unless defined $v;
  $suffix = '.unicharset';
 }
 elsif ( $output =~ /Error\ openn?ing\ data\ file\ (.+)/x ) {
  $output = $1;
  $v      = 3 unless defined $v;
  $suffix = '.traineddata';
 }
 elsif ( defined($v) and version->parse("v$v") > version->parse('v3.01') ) {
  return ( undef, $v, '.traineddata' );
 }
 else {
  return;
 }
 $output =~ s/\/ $suffix $//x;
 return $output, $v, $suffix;
}

sub parse_strings {
 my ($strings) = @_;
 my @strings = split "\n", $strings;
 for (@strings) {
  return $_ . "tessdata" if (/\/ share \//x);
 }
 return;
}

sub languages {
 unless (%languages) {
  my %iso639 = (
   ara        => 'Arabic',
   bul        => 'Bulgarian',
   cat        => 'Catalan',
   ces        => 'Czech',
   chr        => 'Cherokee',
   chi_tra    => 'Chinese (Traditional)',
   chi_sim    => 'Chinese (Simplified)',
   dan        => 'Danish',
   'dan-frak' => 'Danish (Fraktur)',
   deu        => 'German',
   'deu-f'    => 'German (Fraktur)',
   'deu-frak' => 'German (Fraktur)',
   ell        => 'Greek',
   eng        => 'English',
   fin        => 'Finish',
   fra        => 'French',
   heb        => 'Hebrew',
   hin        => 'Hindi',
   hun        => 'Hungarian',
   ind        => 'Indonesian',
   ita        => 'Italian',
   jpn        => 'Japanese',
   kor        => 'Korean',
   lav        => 'Latvian',
   lit        => 'Lituanian',
   nld        => 'Dutch',
   nor        => 'Norwegian',
   pol        => 'Polish',
   por        => 'Portuguese',
   que        => 'Quechua',
   ron        => 'Romanian',
   rus        => 'Russian',
   slk        => 'Slovak',
   'slk-frak' => 'Slovak (Fraktur)',
   slv        => 'Slovenian',
   spa        => 'Spanish',
   srp        => 'Serbian (Latin)',
   swe        => 'Swedish',
   'swe-frak' => 'Swedish (Fraktur)',
   tha        => 'Thai',
   tlg        => 'Tagalog',
   tur        => 'Turkish',
   ukr        => 'Ukranian',
   vie        => 'Vietnamese',
  );

  my @codes;
  if ( version->parse("v$version") > version->parse('v3.02') ) {
   my ( undef, $codes ) =
     Gscan2pdf::Document::open_three("tesseract --list-langs");
   @codes = split "\n", $codes;
   shift @codes if ( $codes[0] =~ /^List\ of\ available\ languages/x );
  }
  else {
   for ( glob "$tessdata/*$datasuffix" ) {

    # Weed out the empty language files
    if ( not -z $_ ) {
     if (/ ([\w\-]*) $datasuffix $/x) {
      push @codes, $1;
     }
    }
   }
  }

  for (@codes) {
   $logger->info("Found tesseract language $_");
   if ( defined $iso639{$_} ) {
    $languages{$_} = $iso639{$_};
   }
   else {
    $languages{$_} = $_;
   }
  }
 }
 return \%languages;
}

sub hocr {

 # can't use the package-wide logger variable as we are in a thread here.
 ( my $class, my $file, my $language, $logger, my $pidfile ) = @_;
 my ( $tif, $cmd, $name, $path );
 Gscan2pdf::Tesseract->setup($logger) unless $setup;

 # Temporary filename for output
 my $suffix =
   version->parse("v$version") >= version->parse("v3") ? '.html' : '.txt';
 my $txt = File::Temp->new( SUFFIX => $suffix );
 ( $name, $path, undef ) = fileparse( $txt, $suffix );

 if ( version->parse("v$version") < version->parse("v3")
  and $file !~ /\.tif$/x )
 {

  # Temporary filename for new file
  $tif = File::Temp->new( SUFFIX => '.tif' );
  my $image = Image::Magick->new;
  $image->Read($file);
  $image->Write( filename => $tif );
 }
 else {
  $tif = $file;
 }
 if ( version->parse("v$version") >= version->parse("v3") ) {
  $cmd =
"echo tessedit_create_hocr 1 > hocr.config;tesseract $tif $path$name -l $language +hocr.config;rm hocr.config";
 }
 elsif ($language) {
  $cmd = "tesseract $tif $path$name -l $language";
 }
 else {
  $cmd = "tesseract $tif $path$name";
 }
 $logger->info($cmd);

 # File in which to store the process ID so that it can be killed if necessary
 $cmd = "echo $$ > $pidfile;$cmd" if ( defined $pidfile );

 my ( $out, $err ) = Gscan2pdf::Document::open_three($cmd);
 my $warnings = $out . $err;
 my $leading  = 'Tesseract Open Source OCR Engine';
 my $trailing = 'with Leptonica';
 $warnings =~ s/$leading v\d\.\d\d $trailing\n//x;
 $warnings =~ s/^Page\ 0\n//x;
 $logger->debug( 'Warnings from Tesseract: ', $warnings );

 return Gscan2pdf::Document::slurp($txt), $warnings;
}

1;

__END__
