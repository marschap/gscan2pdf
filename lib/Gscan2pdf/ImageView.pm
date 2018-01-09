package Gscan2pdf::ImageView;

use warnings;
use strict;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use feature 'switch';
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3;
use List::Util qw(min);

use Glib::Object::Subclass Gtk3::ScrolledWindow::, signals => {
    'zoom-changed' => {
        param_types => ['Glib::Float'],    # new zoom
    },
  },
  properties => [
    Glib::ParamSpec->object(
        'pixbuf',                          # name
        'pixbuf',                          # nickname
        'Pixbuf of image to be shown',     # blurb
        'Gtk3::Gdk::Pixbuf',               # package
        [qw/readable writable/]            # flags
    ),
    Glib::ParamSpec->float(
        'zoom',                            # name
        'zoom',                            # nick
        'zoom level',                      # blurb
        0.001,                             # minimum
        1000.0,                            # maximum
        1.0,                               # default_value
        [qw/readable writable/]            # flags
    ),
  ];

sub INIT_INSTANCE {
    my $self = shift;
    $self->set_hexpand(1);
    $self->set_vexpand(1);
    $self->{image} = Gtk3::Image->new();
    $self->add_with_viewport( $self->{image} );
    $self->signal_connect( 'zoom-changed' => sub { $self->_update_image } );
    return $self;
}

sub SET_PROPERTY {
    my ( $self, $pspec, $newval ) = @_;
    my $name   = $pspec->get_name;
    my $oldval = $self->get($name);
    if (   ( defined $newval and defined $oldval and $newval ne $oldval )
        or ( defined $newval xor defined $oldval ) )
    {
        given ($name) {
            when ('pixbuf') {
                $self->{$name} = $newval;
            }
            when ('zoom') {
                $self->{$name} = $newval;
                $self->signal_emit( 'zoom-changed', $newval );
            }
            default {
                $self->SUPER::SET_PROPERTY( $pspec, $newval );
            }
        }
    }
    return;
}

sub set_pixbuf {
    my ( $self, $pixbuf, $zoom_to_fit ) = @_;
    $self->set( 'pixbuf', $pixbuf );
    if ($zoom_to_fit) {
        $self->zoom_to_fit;
    }
    else {
        $self->_update_image;
    }
    return;
}

sub get_pixbuf {
    my ($self) = @_;
    return $self->get('pixbuf');
}

sub _update_image {
    my ($self) = @_;
    my $pixbuf = $self->get('pixbuf');
    if ( not defined $pixbuf ) { return }
    my $pixb_w = $pixbuf->get_width();
    my $pixb_h = $pixbuf->get_height();
    my $zoom   = $self->get('zoom');
    my $sc_w   = int( $pixb_w * $zoom );
    my $sc_h   = int( $pixb_h * $zoom );
    $pixbuf = $pixbuf->scale_simple( $sc_w, $sc_h, 'GDK_INTERP_HYPER' );
    $self->{image}->set_from_pixbuf($pixbuf);
    return;
}

sub set_zoom {
    my ( $self, $zoom ) = @_;
    $self->set( 'zoom', $zoom );
    return;
}

sub get_zoom {
    my ($self) = @_;
    return $self->get('zoom');
}

sub zoom_to_fit {
    my ($self) = @_;
    my $pixbuf = $self->get('pixbuf');
    if ( not defined $pixbuf ) { return }
    my $max_w       = $self->get_allocation->{width};
    my $max_h       = $self->get_allocation->{height};
    my $pixb_w      = $pixbuf->get_width();
    my $pixb_h      = $pixbuf->get_height();
    my $sc_factor_w = $max_w / $pixb_w;
    my $sc_factor_h = $max_h / $pixb_h;
    $self->set( 'zoom', min( $sc_factor_w, $sc_factor_h ) );
    return;
}

sub zoom_in {
    my ($self) = @_;
    $self->set( 'zoom', $self->get('zoom') * 2 );
    return;
}

sub zoom_out {
    my ($self) = @_;
    $self->set( 'zoom', $self->get('zoom') / 2 );
    return;
}

1;
