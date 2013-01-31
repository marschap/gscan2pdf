package Gscan2pdf::Cuneiform;

use 5.008005;
use strict;
use warnings;
use Carp;
use File::Temp;             # To create temporary files
use Gscan2pdf::Document;    # for slurp
use version;

my ( %languages, $version, $setup, $logger );

sub setup {
 ( my $class, $logger ) = @_;
 return $version if $setup;

 my ( $out, $err ) = Gscan2pdf::Document::open_three('which cuneiform');
 return unless ( defined $out );

 ( $out, $err ) = Gscan2pdf::Document::open_three("cuneiform");
 if ( $out =~ /^Cuneiform\ for\ Linux\ ([\d\.]+)/x ) {
  $version = $1;
 }

 $setup = 1;
 return $version;
}

sub languages {
 unless (%languages) {

  # cuneiform language codes
  my %lang = (
   eng    => 'English',
   ger    => 'German',
   fra    => 'French',
   rus    => 'Russian',
   swe    => 'Swedish',
   spa    => 'Spanish',
   ita    => 'Italian',
   ruseng => 'Russian+English',
   ukr    => 'Ukrainian',
   srp    => 'Serbian',
   hrv    => 'Croatian',
   pol    => 'Polish',
   dan    => 'Danish',
   por    => 'Portuguese',
   dut    => 'Dutch',
   cze    => 'Czech',
   rum    => 'Romanian',
   hun    => 'Hungarian',
   bul    => 'Bulgarian',
   slo    => 'Slovak',
   slv    => 'Slovenian',
   lav    => 'Latvian',
   lit    => 'Lithuanian',
   est    => 'Estonian',
   tur    => 'Turkish',
  );

  # Dig out supported languages
  my $cmd = "cuneiform -l";
  $logger->info($cmd);
  ( my $output, undef ) = Gscan2pdf::Document::open_three($cmd);

  my $langs;
  if ( $output =~ /Supported\ languages:\ (.*)\./x ) {
   $langs = $1;
   for ( split " ", $langs ) {
    if ( defined $lang{$_} ) {
     $languages{$_} = $lang{$_};
    }
    else {
     $languages{$_} = $_;
    }
   }
  }
  else {
   $logger->info("Unrecognised output from cuneiform: $output");
  }
 }
 return \%languages;
}

sub hocr {
 my ( $class, $file, $language, $loggr, $pidfile ) = @_;
 my ($bmp);
 Gscan2pdf::Cuneiform->setup($loggr) unless $setup;

 # Temporary filename for output
 my $txt = File::Temp->new( SUFFIX => '.txt' );

 if ( version->parse("v$version") < version->parse('v1.1.0')
  and $file !~ /\.bmp$/x )
 {

  # Temporary filename for new file
  $bmp = File::Temp->new( SUFFIX => '.bmp' );
  my $image = Image::Magick->new;
  $image->Read($file);

# Force TrueColor, as this produces DirectClass, which is what cuneiform expects.
# Without this, PseudoClass is often produced, for which cuneiform gives
# "PUMA_XFinalrecognition failed" warnings
  $image->Write( filename => $bmp, type => 'TrueColor' );
 }
 else {
  $bmp = $file;
 }
 my $cmd = "cuneiform -l $language -f hocr -o $txt $bmp";
 $logger->info($cmd);
 if ( defined $pidfile ) {
  system("echo $$ > $pidfile;$cmd");
 }
 else {
  system($cmd);
 }
 return Gscan2pdf::Document::slurp($txt);
}

1;

__END__
