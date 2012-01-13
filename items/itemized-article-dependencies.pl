#!/usr/bin/perl -w

use strict;
use File::Basename;

unless (scalar @ARGV == 1) {
  print 'Usage: itemized-article-dependencies.pl ITEMIZED-ARTICLE-DIRECTORY', "\n";
  exit 1;
}

my $article_dir = $ARGV[0];

unless (-d $article_dir) {
  print 'Error: ', $article_dir, ' is not a directory.', "\n";
  exit 1;
}

my $article_basename = basename ($article_dir);

my $map_ckb_script = '/Users/alama/sources/mizar/xsl4mizar/items/map-ckbs.pl';
my $dependencies_script = '/Users/alama/sources/mizar/xsl4mizar/items/dependencies.pl';

unless (-e $map_ckb_script) {
  print 'Error: the item-to-fragment script does not exist at the expected location (', $map_ckb_script, ').', "\n";
  exit 1;
}

unless (-r $map_ckb_script) {
  print 'Error: the item-to-fragment script at ', $map_ckb_script, ' is unreadable.', "\n";
  exit 1;
}

unless (-x $map_ckb_script) {
  print 'Error: the item-to-fragment script at ', $map_ckb_script, ' is not executable.', "\n";
  exit 1;
}

unless (-e $dependencies_script) {
  print 'Error: the dependencies script does not exist at the expected location (', $dependencies_script, ').', "\n";
  exit 1;
}

unless (-r $dependencies_script) {
  print 'Error: the dependencies script at ', $dependencies_script, ' is unreadable.', "\n";
  exit 1;
}

unless (-x $dependencies_script) {
  print 'Error: the dependencies script at ', $dependencies_script, ' is not executable.', "\n";
  exit 1;
}

my @item_to_fragment_lines = `$map_ckb_script $article_dir 2>/dev/null`;

my ($item_to_fragment_exit_code, $item_to_fragment_message) = ($? >> 8, $!);
if ($item_to_fragment_exit_code != 0) {
  print 'Error: something went wrong computing the item-to-fragment table;', "\n";
  print 'the exit code was ', $item_to_fragment_exit_code, ' and the message was:', "\n";
  print $item_to_fragment_message, "\n";
  exit 1;
}

chomp @item_to_fragment_lines;

my %item_to_fragment_table = ();
my %fragment_to_item_table = ();

foreach my $item_to_fragment_line (@item_to_fragment_lines) {
  # Easy: each item comes from exactly one fragment
  (my $item, my $fragment) = split / => /, $item_to_fragment_line;
  $item_to_fragment_table{$item} = $fragment;

  # Less easy: some fragments (specifically, definition blocks)
  # generate multiple items
  my @generated_items;
  if (defined $fragment_to_item_table{$fragment}) {
    @generated_items = @{$fragment_to_item_table{$fragment}};
  } else {
    @generated_items = ();
  }
  push (@generated_items, $item);
  $fragment_to_item_table{$fragment} = \@generated_items;
}

sub resolve_item {
  my $item = shift;
  my $resolved;
  if ($item =~ /^ckb[0-9]+:/) {
    # We have some resolving to do
    $item =~ m/^ckb([0-9]+):([^:]+):/;
    (my $item_fragment_num, my $item_kind) = ($1, $2);
    unless (defined $item_fragment_num && defined $item_kind) {
      print "\n";
      print 'Error: we could not extract the fragment number and item kind from the string "', $item, '"', "\n";
      exit 1;
    }
    my $item_fragment = "${article_basename}:fragment:${item_fragment_num}";
    if (defined $fragment_to_item_table{$item_fragment}) {
      my @generated_items = @{$fragment_to_item_table{$item_fragment}};
      if (scalar @generated_items == 0) {
        print "\n";
        print 'Error: somehow the entry in the fragment-to-item table for ', $item_fragment, ' is an empty list.', "\n";
        exit 1;
      }
      if (scalar @generated_items == 1) {
        # Easy: the dependent fragment generated exactly one item;
        # $item depends on it
        $resolved = $generated_items[0];
      } else {
        # Less easy: the dependent item generated more than one
        # item; we need to find the one that is congruent with
        # $dep_fragment.
        my @candidate_items = grep (/:${item_kind}:/, @generated_items);
        if (scalar @candidate_items == 0) {
          print "\n";
          print 'Error: there are no candidate matches for ', $item_fragment, ' in the fragment-to-item table.', "\n";
          exit 1;
        }
        if (scalar @candidate_items > 1) {
          print "\n";
          print 'Error: there are multiple candidate matches for ', $item_fragment, ' in the fragment-to-item table:', "\n";
          foreach my $candidate (@candidate_items) {
            print '* ', $candidate, "\n";
          }
          print 'We require that there be exactly one.', "\n";
          exit 1;
        }

        $resolved = $candidate_items[0];
      }
    } else {
      print 'Error: the fragment-to-item table does not contain ', $item, '.', "\n";
      exit 1;
    }
  } else {
    $resolved = $item;
  }
  return $resolved;
}

foreach my $item (keys %item_to_fragment_table) {
  my $fragment = $item_to_fragment_table{$item};
  $fragment =~ m/^${article_basename}:fragment:([0-9]+)$/;
  my $fragment_number = $1;
  unless (defined $fragment_number) {
    print 'Error: we could not extract the article fragment number from the text', "\n";
    print '  ', $fragment, "\n";
    exit 1;
  }
  my $fragment_miz = "${article_dir}/text/ckb${fragment_number}.miz";
  unless (-e $fragment_miz) {
    print 'Error: the .miz file for fragment ', $fragment_number, ' of ', $article_basename, ' does not exist at the expected location (', $fragment_miz, ').', "\n";
    exit 1;
  }
  my @fragment_dependencies = `$dependencies_script $fragment_miz 2> /dev/null`;
  (my $dependencies_exit_code, my $dependencies_message) = ($? >> 8, $!);
  if ($dependencies_exit_code != 0) {
    print 'Error: something went wrong when calling the dependencies script on fragment ', $fragment_number, ' of ', $article_basename, ';', "\n";
    print 'The exit code was ', $dependencies_exit_code, ' and the message was:', "\n";
    print $dependencies_message, "\n";
    exit 1;
  }

  print $item;
  chomp @fragment_dependencies;
  if (scalar @fragment_dependencies > 0) {
    foreach my $dep (@fragment_dependencies) {
      my $resolved_dep = resolve_item ($dep);

      unless (defined $resolved_dep) {
        print "\n";
        print 'Error: we were unable to resolve the item ', $dep, '.', "\n";
        exit 1;
      }

      # Special case: if we are computing the dependencies of a
      # pattern, then print only constructors and other
      # patterns.
      if ($item =~ /:.pattern:/) {
        if ($resolved_dep =~ /:.pattern:/ || $resolved_dep =~ /:.constructor:/) {
          print ' ', $resolved_dep;
        }
      } else {
        print ' ', $resolved_dep;
      }
    }
    print "\n";
  }
}

__END__

=head1 ITEMIZED-ARTICLE-DEPENDENCIES

itemized-article-dependencies.pl - Print the dependencies of an itemized Mizar article

=head1 SYNOPSIS

itemized-article-dependencies.pl [options] directory

Interpret the supplied directory as the result of itemizing a Mizar
article, and print the dependencies of each of the microarticles under
the supplied directory.

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--verbose>

Say what we're doing as we're doing it.

=item B<--script-home=DIR>

The directory in which we will look for the needed auxiliary scripts.

=item B<--stylesheet-home=DIR>

The directory in which we will look for any needed auxiliary
stylesheets.

=back

=head1 DESCRIPTION

B<itemized-article-dependencies.pl> will consult the given article as
well as its environment to determine the article's dependencies, which
it prints (one per line) to standard output.

=head1 REQUIRED ARGUMENTS

It is necessary to supply a directory as the one and only argument of
this program.  The directory is supposed to be the result of itemizing
a Mizar article.  It should have the structure of a multi-article
Mizar development: there should be subdirectories 'prel', 'dict', and
'text'.

=head1 SEE ALSO

=over 8

=item F<dependencies.pl>

=item L<http://mizar.org/>

=back

=cut
