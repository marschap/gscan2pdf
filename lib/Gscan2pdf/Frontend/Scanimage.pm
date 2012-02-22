package Gscan2pdf::Frontend::Scanimage;

use strict;
use warnings;
use Carp;
use base qw(Exporter);

BEGIN {
 use Exporter ();
 our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

 # set the version for version checking
 # $VERSION     = 0.01;

 %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

 # your exported package globals go here,
 # as well as any optionally exported functions
 @EXPORT_OK = qw();
}
our @EXPORT_OK;

# return a hash of the passed options

sub options2hash {

 my ($output) = @_;
 my %hash;
 while (
  $output =~ /
                      -+        # at least one dash
                      ([\w\-]+) # the option name
                      \ ?       # an optional space
                      (.*)      # possible values
                      \         # a space
                      \[(.*)\]  # the default value, surrounded by square brackets
                      \ *\n     # the rest of the line
                      ([\S\s]*) # the rest of the output
                    /x
   )
 {
  my $option  = $1;
  my $values  = $2;
  my $default = $3;

  # Remove everything on the option line and above.
  $output = $4;

  # Strip out the extra characters by e.g. [=(yes|no)]
  $values = $1
    if (
   $values =~ /
                                 \[   # an opening square bracket
                                 =    # an equals sign
                                 \(   # an opening round bracket
                                 (.*) # the options
                                 \)   # a closing round bracket
                                 \]   # a closing square bracket
                               /x
    );

  if (
   $values =~ /
                    (-?\d*\.?\d*)          # min value, possibly negative or floating
                    \.\.                   # two dots
                    (\d*\.?\d*)            # max value, possible floating
                    (pel|bit|mm|dpi|%|us)? # optional unit
                  /x
    )
  {
   $hash{$option}{min}  = $1;
   $hash{$option}{max}  = $2;
   $hash{$option}{unit} = $3 if ( defined $3 );
   $hash{$option}{step} = $1
     if (
    $values =~ /
                       \(              # opening round bracket
                       in\ steps\ of\  # text
                       (\d*\.?\d+)     # step
                       \)              # closing round bracket
                     /x
     );
  }
  else {
   my @array;
   while ( defined $values ) {
    my $i = index( $values, '|' );
    my $value;
    if ( $i > -1 ) {
     $value  = substr( $values, 0,      $i );
     $values = substr( $values, $i + 1, length($values) );
    }
    else {
     if ( $values =~ /(pel|bit|mm|dpi|%|us)$/x ) {
      $hash{$option}{unit} = $1;
      $values = substr( $values, 0, index( $values, $hash{$option}{unit} ) );
     }
     $value = $values;
     undef $values;
    }
    push @array, $value if ( $value ne '' );
   }
   $hash{$option}{values} = [@array] if (@array);
  }

  # Parse tooltips from option description based on an 8-character indent.
  my $tip = '';
  while (
   $output =~ /
                       ^\ {8,}   # 8-character indent
                       (.*)\n    # text
                       ([\S\s]*) # rest of output
                     /x
    )
  {
   if ( $tip eq '' ) {
    $tip = $1;
   }
   else {
    $tip = "$tip $1";
   }

   # Remove everything on the description line and above.
   $output = $2;
  }

  $hash{$option}{default} = $default;
  $hash{$option}{tip}     = $tip;
 }
 return %hash;
}

1;

__END__
