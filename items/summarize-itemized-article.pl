#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use Pod::Usage;
use Carp qw(croak);

my $man = 0;
my $help = 0;

GetOptions('help|?' => \$help,
           'man' => \$man)
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
pod2usage(1) unless (scalar @ARGV == 1);

my $itemized_article_directory = $ARGV[0];

if (! -e $itemized_article_directory) {
  croak ('Error: the supplied itemized article directory ', $itemized_article_directory, ' does not exist.');
}

if (! -d $itemized_article_directory) {
  croak ('Error: the supplied itemized article directory ', $itemized_article_directory, ' is not actually a directory.');
}

my $prel_subdir = "${itemized_article_directory}/prel";
my $text_subdir = "${itemized_article_directory}/text";

if (! -e $prel_subdir) {
  croak ('Error: there is no prel subdirectory of ', $itemized_article_directory, '.');
}

if (! -d $prel_subdir) {
  croak ('Error: there is no prel subdirectory of ', $itemized_article_directory, '.');
}

if (! -e $text_subdir) {
  croak ('Error: there is no prel subdirectory of ', $itemized_article_directory, '.');
}

if (! -d $text_subdir) {
  croak ('Error: there is no prel subdirectory of ', $itemized_article_directory, '.');
}

sub ckb_number {
  my $ckb = shift;
  if ($ckb =~ / \A ckb ([0-9]+) \z /x) {
    return $1;
  } else {
    croak ('Error: unable to make sense of the fragment name \'', $ckb, '\'.');
  }
}

sub ckb_cmp {
  my $ckb_num_1 = ckb_number ($a);
  my $ckb_num_2 = ckb_number ($b);
  if ($ckb_num_1 < $ckb_num_2) {
    return -1;
  } elsif ($ckb_num_1 == $ckb_num_2) {
    return 0;
  } else {
    return 1;
  }
}

sub item_for_fragment {
  my $fragment = shift;
  return $fragment;
}

my @fragments = `find $text_subdir -maxdepth 1 -mindepth 1 -type f -name "ckb*.miz" -exec basename {} .miz ';'`;
chomp @fragments;
my @sorted_fragments = sort ckb_cmp @fragments;

my $num_fragments = scalar @sorted_fragments;

foreach my $fragment (@sorted_fragments) {
  my $fragment_number = ckb_number ($fragment);
  my @prels_for_fragment = `find $prel_subdir -mindepth 1 -maxdepth 1 -type f -name "${fragment}.*" -exec basename {} ';'`;
  if (scalar @prels_for_fragment == 0) {
    print $fragment_number, ' ==>', "\n";
  } else {
    print $fragment_number, ' ==>';
    foreach my $prel_for_fragment (@prels_for_fragment) {
      my $item = item_for_fragment ($fragment);
      print ' ', $item;
    }
    print "\n";
  }
}

__END__

=pod

=encoding utf8

=head1 NAME

summarize-itemized-article.pl - Say how an itemized article generates items from its fragments

=head1 USAGE

summarize-itemized-article.pl [options] mizar-article

=head1 REQUIRED ARGUMENTS

A Mizar article, as a path, must be supplied.

=head1 ENVIRONMENT

No environment variables are consulted.

=back

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<summarize-itemized-article.pl> takes the name of a directory.  The
output, if the given directory is the result of itemizing a Mizar
article, is an explanation for how the itemized article's fragments
generate items.  The result will be a list of 0 or more lines of the form

=over 4

<number> ==> <item-1>,<item-2>,...,<item-N>

=back

when the fragment # <number> generates the items <item-1>, <item-2>,
..., <item-N>.  If a fragment generates no items, the output line will
be

=over 4

<number> ==>

=back

with a newline immediately after the '>' of '==>'.

=head1 EXIT STATUS

0 if everything went OK, 1 if any error occurred, 2 if improper
commandline arguments was given.  No other exit codes are used.

=head1 INCOMPATIBILITIES

None known.

=head1 AUTHOR

Jesse Alama <jesse.alama@gmail.com>

=head1 LICENSE AND COPYRIGHT

This source is offered under the terms of
L<the GNU GPL version 3|http://www.gnu.org/licenses/gpl-3.0.en.html>.

=cut
