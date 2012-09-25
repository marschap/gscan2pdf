package Gscan2pdf::PageRange;

use strict;
use warnings;
use Gtk2;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE

# Note: in a BEGIN block to ensure that the registration is complete
#       by the time the use Subclass goes to look for it.
BEGIN {
 Glib::Type->register_enum( 'Gscan2pdf::PageRange::Range', qw(selected all) );
}

# this big hairy statement registers our Glib::Object-derived class
# and sets up all the signals and properties for it.
use Glib::Object::Subclass Gtk2::VBox::,
  signals    => { changed => {}, },
  properties => [
 Glib::ParamSpec->enum(
  'active',                    # name
  'active',                    # nickname
  'Either selected or all',    #blurb
  'Gscan2pdf::PageRange::Range',
  'selected',                  # default
  [qw/readable writable/]      #flags
 ),
  ];

sub INIT_INSTANCE {
 my $self    = shift;
 my $d       = Locale::gettext->domain(Glib::get_application_name);
 my %buttons = (
  'selected' => $d->get('Selected'),
  'all'      => $d->get('All'),
 );
 my $vbox = Gtk2::VBox->new;
 $self->add($vbox);

 #the first radio button has to set the group,
 #which is undef for the first button
 my $group;
 foreach my $nick ( keys %buttons ) {
  $self->{button}{$nick} = Gtk2::RadioButton->new( $group, $buttons{$nick} );
  $self->{button}{$nick}->signal_connect(
   'toggled' => sub {
    $self->set_active($nick) if ( $self->{button}{$nick}->get_active );
   }
  );
  $vbox->pack_start( $self->{button}{$nick}, TRUE, TRUE, 0 );
  $group = $self->{button}{$nick}->get_group unless ($group);
  $self->{active} = $nick unless ( $self->{active} );
 }
 return;
}

sub get_active {
 my ($self) = @_;
 return $self->get('active');
}

sub set_active {
 my ( $self, $active ) = @_;
 $self->{active} = $active;
 foreach my $nick ( keys %{ $self->{button} } ) {
  if ( $self->{active} eq $nick ) {
   $self->{button}{$nick}->set_active(TRUE);
   $self->signal_emit('changed');
  }
 }
 return;
}

1;

__END__
