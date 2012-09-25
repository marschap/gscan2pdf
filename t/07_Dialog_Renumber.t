use warnings;
use strict;
use Test::More tests => 3;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;

BEGIN {
 use_ok('Gscan2pdf::Dialog::Renumber');
}

#########################

my $window = Gtk2::Window->new;

ok(
 my $dialog = Gscan2pdf::Dialog::Renumber->new(
  title           => 'title',
  'transient-for' => $window
 ),
 'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Renumber' );

__END__
