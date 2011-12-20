#!/usr/bin/perl -w

use strict;
use File::Basename qw(basename dirname);
use File::Copy qw(copy move);
use Getopt::Long;
use Pod::Usage;

=cut

=head1 minimize-itemized-article.pl

minimize-itemized-article.pl - Minimize the fragments of an "itemized" mizar article

=head1 SYNOPSIS

minimize-itemized-article.pl [options] itemized-mizar-article-directory

Options:

  -help                       Brief help message

  -man                        Full documentation

  -verbose                    Say what we're doing

  -minimize-whole-article     Minimize the whole article and use its minimal environment in minimizing its fragments

  -paranoid                   Check that the minimized fragments are verifiable

  -script-home                Directory in which to look for auxiliary scripts

  -stylesheet-home            Directory in which to look for needed stylesheets

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--verbose>

Say what environment file we're minimizing, and for each environment
file, say how many environment "items" are present there and how many
we really need.

=item B<--minimize-whole-article>

Before minimizing the environment of each of the items from an
article, minimize the whole article and use its minimal environment as
a basis for each of the article's item's environment.

Such minimization may an expensive up-front cost, but it can save time
in the long run, depending on the size of the original article's
environment and how expensive it is to verify it.

=item B<--paranoid>

Call the verifier on each of the itemized articles.

=item B<--script-home=DIR>

The directory in which we will look for any needed scripts.

=item B<--stylesheet-home=DIR>

The directory in which we will look for any needed stylesheets.

=back

=head1 DESCRIPTION

B<minimize-itemized-article.pl> will construct, for each fragment of
an itemized mizar article, the smallest environment with respect to
which the given article is verifiable.

=cut

my $verbose = 0;
my $man = 0;
my $help = 0;
my $paranoid = 0;
my $minimize_whole_article = 0;
my $script_home = '/Users/alama/sources/mizar/xsl4mizar/items';
my $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/items';

GetOptions('help|?' => \$help,
           'man' => \$man,
           'verbose'  => \$verbose,
           'minimize-whole-article' => \$minimize_whole_article,
	   'script-home=s' => \$script_home,
	   'stylesheet-home=s' => \$stylesheet_home)
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

if (scalar @ARGV != 1) {
  print 'Usage: minimize-itemized-article.pl ITEMIZED-ARTICLE-DIRECTORY', "\n";
  exit 1;
}

my $article_dir = $ARGV[0];

unless (-d $article_dir) {
  print 'Error: the supplied itemized-article directory ', $article_dir, ' is not actually directory.', "\n";
  exit 1;
}

my $article_text_dir = "${article_dir}/text";

unless (-d $article_text_dir) {
  print 'Error: there is no text subdirectory of ', $article_dir, ', so it is not an itemized article directory.', "\n";
  exit 1;
}

my @miz_candidates = `find $article_dir -maxdepth 1 -mindepth 1 -type f -name "*.miz"`;
chomp @miz_candidates;

if (scalar @miz_candidates == 0) {
  print 'Error: we did not find any .miz files under $article_dir.', "\n";
  exit 1;
}

if (scalar @miz_candidates > 1) {
  print 'Error: we found multiple .miz files under $article_dir; which one should we use?', "\n";
  exit 1;
}

my $itemized_article_miz = $miz_candidates[0];
my $itemized_article_basename = basename ($itemized_article_miz, '.miz');

unless (-e $itemized_article_miz) {
  print 'Error: there is no article by the name \'', $itemized_article_basename, '\' under ', $article_dir, '.', "\n";
  exit 1;
}

unless (-r $itemized_article_miz) {
  print 'Error: the itemized article at ', $itemized_article_miz, ' is unreadable.', "\n";
  exit 1;
}

unless (-d $script_home) {
  print 'Error: the supplied directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for auxiliary scripts is not actually a directory.', "\n";
  exit 1;
}

my $minimize_script = "${script_home}/minimal.pl";

unless (-e $minimize_script) {
  print 'Error: the minimization script does not exist at the expected location (', $minimize_script, ').', "\n";
  exit 1;
}

unless (-r $minimize_script) {
  print 'Error: the minimization script at ', $minimize_script, ' is unreadable.', "\n";
  exit 1;
}

unless (-x $minimize_script) {
  print 'Error: the minimization script at ', $minimize_script, ' is not executable.', "\n";
  exit 1;
}

unless (-d $stylesheet_home) {
  print 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheet is not actually a directory.', "\n";
  exit 1;
}

my $prefer_environment_stylesheet = "${stylesheet_home}/prefer-environment.xsl";

unless (-e $prefer_environment_stylesheet) {
  print 'Error: the prefer-environment stylesheet does not exist at the expected location (', $prefer_environment_stylesheet, ').', "\n";
  exit 1;
}

unless (-r $prefer_environment_stylesheet) {
  print 'Error: the prefer-environment stylesheet at ', $prefer_environment_stylesheet, ' is unreadable.', "\n";
  exit 1;
}


my @fragments = `find $article_text_dir -name "ckb*.miz"`;
chomp @fragments;

if (scalar @fragments == 0) {
  print 'Error: we found 0 fragments under ', $article_text_dir, '.', "\n";
  exit 1;
}

if ($minimize_whole_article == 1) {

  if ($verbose == 1) {
    print 'Minimizing the itemized article...', "\n";
  }

  my $minimize_call =
    ($verbose == 1) ? "$minimize_script --verbose $itemized_article_miz"
                    : "$minimize_script $itemized_article_miz";

  my $minimize_status = system ($minimize_call);
  my $minimize_exit_code = $minimize_status >> 8;

  if ($minimize_exit_code != 0) {
    print 'Error: minimization of the itemized article ', $itemized_article_miz, ' did not exit cleanly.', "\n";
    exit 1;
  }

  if ($paranoid == 1) {
    my $verifier_status = system ("verifier -q -s -l $itemized_article_miz > /dev/null 2>&1");
    my $verifier_exit_code = $verifier_status >> 8;
    if ($verifier_exit_code != 0) {
      print 'Error: the minimized whole article is not verifiable!', "\n";
      exit 1;
    }
  }

  if ($verbose == 1) {
    print 'Done minimizing the itemized article.', "\n";
  }

  my @extensions = ('eno', 'erd', 'epr', 'dfs', 'eid', 'ecl');

  if ($verbose == 1) {
    print 'Rewriting each fragment\'s environment to use the minimized article\'s environment...';
  }

  foreach my $fragment (@fragments) {
    my $fragment_basename = basename ($fragment);
    foreach my $extension (@extensions) {
      my $fragment_with_extension = "${article_text_dir}/${fragment_basename}.${extension}";
      my $fragment_with_extension_orig = "${article_text_dir}/${fragment_basename}.${extension}.orig";
      my $fragment_with_extension_tmp = "${article_text_dir}/${fragment_basename}.${extension}.tmp";
      my $article_with_extension = "${article_dir}/${itemized_article_basename}.${extension}";
      if (-e $article_with_extension && -e $fragment_with_extension) {
        copy ($fragment_with_extension, $fragment_with_extension_orig);

        my $xsltproc_status = system ("xsltproc --output $fragment_with_extension_tmp --stringparam original-environment '$article_with_extension' $fragment_with_extension_tmp");
        my $xsltproc_exit_code = $xsltproc_status >> 8;
        if ($xsltproc_exit_code != 0) {
          print 'Error: xsltproc did not exit cleanly when rewriting the .', $extension, ' file for ', $fragment, '.', "\n";
          exit 1;
        }

        move ($fragment_with_extension_tmp, $fragment_with_extension);

        if ($paranoid == 1) {
          # Sanity check: the fragment with the new environment is verifiable
          my $verifier_status = system ("verifier -q -s -l $fragment > /dev/null 2>&1");
          my $verifier_exit_code = $verifier_status >> 8;
          if ($verifier_exit_code != 0) {
            print 'Error: we are unable to verify ', $fragment, ' with its new environment.', "\n";
            exit 1;
          }
        }

      }
    }
  }

  if ($verbose == 1) {
    print 'done.', "\n";
  }

}

my $parallel_call =
  ($verbose == 1) ? "find ${article_text_dir} -name 'ckb*.miz' | parallel --eta ${minimize_script} {}"
                  : "find ${article_text_dir} -name 'ckb*.miz' | parallel ${minimize_script} {}";

my $parallel_minimize_status = system ($parallel_call);
my $parallel_minimize_exit_code = $parallel_minimize_status >> 8;

if ($parallel_minimize_exit_code != 0) {
  print 'Error: parallel did not exit cleanly when minimizing the fragments under ', $article_text_dir, '.', "\n";
  exit 1;
}

if ($verbose == 1) {
  print 'Done.', "\n";
}

exit 0;
