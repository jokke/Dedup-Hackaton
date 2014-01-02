package App::DDup::Settings;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

with 'MooseX::Getopt::Usage';
with 'MooseX::Getopt::Usage::Role::Man';

my $format_constraint = subtype as 'Str', where { $_ =~ /^(human|robot)$/ };

has head_size => (
    is  => 'rw',
    isa => 'Int',
    default => 4096, #sub { 4096; },
    documentation => 'Use this max length (bytes) when looking into a files.'
);

has block_size => (
    is  => 'rw',
    isa => 'Int',
    default => 65536,
    documentation => 'Use block size (bytes) to reading files.'
);

has dir => (
    is  => 'rw',
    isa => 'Str',
    required => 1,
    documentation => 'Directory to search.'
);

has remove => (
    is  => 'rw',
    isa => 'Bool',
    documentation => 'Delete the identified duplicates.'
);

has format => (
    is  => 'rw',
    isa => 'Str',
    default => 'robot',
    documentation => 'Output format to use (human or robot).',
);

has checksum => (
    is  => 'rw',
    isa => 'Str',
    default => 'Digest::xxHash',
    documentation => 'Digest algorithm to use (Digest::MD5, Digest::SHA1 or Digest::xxHash). While xxHash is faster, MD5 is more reliable.',
);

has threads => (
    is  => 'rw',
    isa => 'Int',
    default => '1',
    documentation => 'How many threads to use (if your perl supports threads).'
);

=pod
  
=head1 SYNOPSIS
    
 %c [OPTIONS] FILES 
       
=head1 DESCRIPTION

Identifying duplicated files in a given directory with the option of removing
the duplicates. Developed as a submission to the DFW hackathon.
 
=head1 AUTHOR

Joakim Lagerqvist <jokke@cpan.org>

=head1 LICENSE

This library is free software and may be distributed under the same terms as perl itself.

=cut
__PACKAGE__->meta->make_immutable;

1;
