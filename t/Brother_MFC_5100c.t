# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 16;
BEGIN { use_ok('Gscan2pdf') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/Brother_MFC_5100c';
my $output = do { local( @ARGV, $/ ) = $filename ; <> } ;
my %this = Gscan2pdf::options2hash($output);
my %that = (
          'source' => {
                        'tip' => 'Selects the scan source (such as a document-feeder).',
                        'default' => 'Automatic Document Feeder',
                        'values' => 'FlatBed|Automatic Document Feeder'
                      },
          'brightness' => {
                            'tip' => 'Controls the brightness of the acquired image.',
                            'default' => 'inactive',
                            'values' => '-50..50% (in steps of 1)'
                          },
          'mode' => {
                      'tip' => 'Select the scan mode',
                      'default' => '24bit Color',
                      'values' => 'Black & White|Gray[Error Diffusion]|True Gray|24bit Color'
                    },
          'resolution' => {
                            'tip' => 'Sets the resolution of the scanned image.',
                            'default' => '200',
                            'values' => '100|150|200|300|400|600|1200|2400|4800|9600dpi'
                          },
          'contrast' => {
                          'tip' => 'Controls the contrast of the acquired image.',
                          'default' => 'inactive',
                          'values' => '-50..50% (in steps of 1)'
                        }
        );
foreach my $option (keys %this) {
 foreach (qw(tip default values)) {
  is ($this{$option}{$_}, $that{$option}{$_}, "$option, $_");
 }
}
eq_hash(\%this, \%that);
