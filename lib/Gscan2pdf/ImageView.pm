package Gscan2pdf::ImageView;

use strict;
use warnings;
use feature 'switch';
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3;
use List::Util qw(min);

use Glib::Object::Subclass Gtk3::ScrolledWindow::,
  signals    => {},
  properties => [
    Glib::ParamSpec->object(
        'pixbuf',                         # name
        'pixbuf',                         # nickname
        'Pixbuf of image to be shown',    # blurb
        'Gtk3::Gdk::Pixbuf',              # package
        [qw/readable writable/]           # flags
    ),
  ];

sub INIT_INSTANCE {
    my $self = shift;
    $self->set_hexpand(1);
    $self->set_vexpand(1);
    $self->{image} = Gtk3::Image->new();
    $self->add_with_viewport( $self->{image} );
    return $self;
}

sub set_pixbuf {
    my ( $self, $pixbuf ) = @_;
    $self->set( 'pixbuf', $pixbuf );
    $self->update_image;
    return;
}

sub update_image {
    my ($self) = @_;
    my $pixbuf = $self->get('pixbuf');
    if ( not defined $pixbuf ) { return }
    my $max_w  = $self->get_allocation()->{width};
    my $max_h  = $self->get_allocation()->{height};
    my $pixb_w = $pixbuf->get_width();
    my $pixb_h = $pixbuf->get_height();
    if ( $pixb_w > $max_w or $pixb_h > $max_h ) {
        my $sc_factor_w = $max_w / $pixb_w;
        my $sc_factor_h = $max_h / $pixb_h;
        my $sc_factor   = min( $sc_factor_w, $sc_factor_h );
        my $sc_w        = int( $pixb_w * $sc_factor );
        my $sc_h        = int( $pixb_h * $sc_factor );
        my $pixbuf = $pixbuf->scale_simple( $sc_w, $sc_h, 'GDK_INTERP_HYPER' );
    }
    $self->{image}->set_from_pixbuf($pixbuf);
    return;
}

1;
