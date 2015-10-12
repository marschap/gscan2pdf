use warnings;
use strict;
use Test::More tests => 5;

BEGIN {
    use Gtk2 -init;
    use_ok('Gscan2pdf::EntryCompletion');
}

#########################

my @list = qw(one two three);
my $entry = Gscan2pdf::EntryCompletion->new( 'new', \@list );

#########################

$entry->set_text('four');
is $entry->update( \@list ), 'four', 'returned text';
my @example = qw(one two three four);
is_deeply( \@list, \@example, 'updated suggestions' );

#########################

$entry->set_text('two');
is $entry->update( \@list ), 'two', 'returned text again';
is_deeply( \@list, \@example, 'ignored duplicates in suggestions' );

#########################

__END__
