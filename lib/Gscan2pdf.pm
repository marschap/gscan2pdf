package Gscan2pdf;

use strict;
use warnings;
use Carp;


BEGIN {
 use Exporter ();
 our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS);

 # set the version for version checking
# $VERSION     = 0.01;

 @ISA         = qw(Exporter);
 %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

 # your exported package globals go here,
 # as well as any optionally exported functions
 @EXPORT_OK   = qw();
}
our @EXPORT_OK;


# return a hash of the passed options

sub options2hash {

 my ($output) = @_;
 my %hash;
 while ($output =~ /-+([\w\-]+) ?(.*) \[(.*)\] *\n([\S\s]*)/) {
  my $option = $1;
  my $values = $2;
  my $default = $3;

# Remove everything on the option line and above.
  $output = $4;

# Strip out the extra characters by e.g. [=(yes|no)]
  $values = $1 if ($values =~ /\[=\((.*)\)\]/);

  if ($values =~ /(-?\d*\.?\d*)\.\.(\d*\.?\d*)(pel|bit|mm|dpi|%|us)?/) {
   $hash{$option}{min} = $1;
   $hash{$option}{max} = $2;
   $hash{$option}{unit} = $3 if (defined $3);
   $hash{$option}{step} = $1
    if ($values =~ /\(in steps of (\d*\.?\d+)\)/);
  }
  else {
   my @array;
   while (defined $values) {
    my $i = index($values, '|');
    my $value;
    if ($i > -1) {
     $value = substr($values, 0, $i);
     $values = substr($values, $i+1, length($values));
    }
    else {
     if ($values =~ /(pel|bit|mm|dpi|%|us)$/) {
      $hash{$option}{unit} = $1;
      $values = substr($values, 0, index($values, $hash{$option}{unit}));
     }
     $value = $values;
     undef $values;
    }
    push @array, $value if ($value ne '');
   }
   $hash{$option}{values} = [ @array ] if (@array);
  }

# Parse tooltips from option description based on an 8-character indent.
  my $tip = '';
  while ($output =~ /^ {8,}(.*)\n([\S\s]*)/) {
   if ($tip eq '') {
    $tip = $1;
   }
   else {
    $tip = "$tip $1";
   }

# Remove everything on the description line and above.
   $output = $2;
  }

  $hash{$option}{default} = $default;
  $hash{$option}{tip} = $tip;
 }
 return %hash;
}

1;


__END__
