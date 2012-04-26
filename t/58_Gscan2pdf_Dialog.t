use warnings;
use strict;
use Test::More tests => 16;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;

BEGIN {
 use_ok('Gscan2pdf::Dialog');
}

#########################

my $window = Gtk2::Window->new;

ok(
 my $dialog =
   Gscan2pdf::Dialog->new( title => 'title', 'transient-for' => $window ),
 'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog' );

is( $dialog->get('title'),         'title', 'title' );
is( $dialog->get('transient-for'), $window, 'transient-for' );
ok( $dialog->get('destroy') == TRUE, 'default destroy' );
is( $dialog->get('border-width'), 0, 'default border width' );

ok( my $vbox = $dialog->get('vbox'), 'Get vbox' );
isa_ok( $vbox, 'Gtk2::VBox' );
is(
 $vbox->get('border-width'),
 $dialog->get('border-width'),
 'border width applied to vbox'
);

my $border_width = 6;
$dialog->set( 'border-width', $border_width );
is( $dialog->get('border-width'), $border_width, 'set border width' );
is( $vbox->get('border-width'),
 $border_width, 'new border width applied to vbox' );

$dialog->signal_emit('destroy');
require Scalar::Util;
Scalar::Util::weaken($dialog);
is( $dialog, undef, 'destroyed' );

$dialog =
  Gscan2pdf::Dialog->new( title => 'title', 'transient-for' => $window );
$dialog->signal_emit( 'delete_event', undef );
Scalar::Util::weaken($dialog);
is( $dialog, undef, 'destroyed on delete_event' );

$dialog = Gscan2pdf::Dialog->new(
 title           => 'title',
 'transient-for' => $window,
 destroy         => FALSE
);
$dialog->signal_emit('destroy');
Scalar::Util::weaken($dialog);
isnt( $dialog, undef, 'hidden on destroy signal' );

$dialog->signal_emit( 'delete_event', undef );
isnt( $dialog, undef, 'hidden on delete_event' );

__END__
