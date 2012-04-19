package Gscan2pdf::Dialog;

use Gtk2;
use Carp;

use Glib::Object::Subclass Gtk2::Window::;

sub new {
 my $class  = shift;
 my $self   = $class->SUPER::new;
 my %params = @_;
 croak "Error: no parent window supplied" unless ( defined $params{parent} );
 croak "Error: no title supplied"         unless ( defined $params{title} );

 $self->set_border_width( $params{border_width} )
   if ( defined $params{border_width} );
 $self->set_title( $params{title} );
 $self->set_transient_for( $params{parent} );
 $self->set_position('center-on-parent');

 if ( defined( $params{destroy} ) and $params{destroy} ) {
  $self->signal_connect( destroy => sub { $self->destroy; } );
  $self->signal_connect(
   key_press_event => sub {
    my ( $widget, $event ) = @_;
    return unless $event->keyval == $Gtk2::Gdk::Keysyms{Escape};
    $self->destroy;
   }
  );
 }
 else {
  $self->signal_connect(
   delete_event => sub {
    $self->hide;
    return TRUE;    # ensures that the window is not destroyed
   }
  );
  $self->signal_connect(
   key_press_event => sub {
    my ( $widget, $event ) = @_;
    return unless $event->keyval == $Gtk2::Gdk::Keysyms{Escape};
    $self->hide;
    return TRUE;    # ensures that the window is not destroyed
   }
  );
 }

 # VBox for window
 my $vbox = Gtk2::VBox->new;
 $self->add($vbox);
 $self->{vbox} = $vbox;
 bless( $self, $class );
 return $self;
}

sub vbox {
 my $self = shift;
 return $self->{vbox};
}

1;

__END__
