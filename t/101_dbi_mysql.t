use strict;
use warnings;
use lib './t';
use FindBin::libs;
use Data::Dumper;
use Perl6::Say;
use Test::More tests => 11;
use Test::Exception;

use DBI;
use DBIx::Skinny::Schema::Loader::DBI::mysql;
use Mock::MySQL;

END { Mock::MySQL->clean_test_db }

SKIP : {
    my $testdsn  = $ENV{ SKINNY_MYSQL_DSN  } || 'dbi:mysql:test';
    my $testuser = $ENV{ SKINNY_MYSQL_USER } || '';
    my $testpass = $ENV{ SKINNY_MYSQL_PASS } || '';

    skip 'Set $ENV{SKINNY_MYSQL_DSN}, _USER and _PASS to run this test', 11 unless ($testdsn && $testuser);

    ok my $dbh = DBI->connect($testdsn, $testuser, $testpass), 'connected to MySQL';
    Mock::MySQL->dbh($dbh);
    Mock::MySQL->setup_test_db;

    throws_ok { DBIx::Skinny::Schema::Loader::DBI::mysql->new({ dsn => '', user => '', pass => '' }) }
        qr/^Can't connect to data source/,
        'failed to connect DB';

    ok my $loader = DBIx::Skinny::Schema::Loader::DBI::mysql->new({
            dsn => $testdsn, user => $testuser, pass => $testpass
        }), 'created loader object';
    is_deeply $loader->tables, [qw/authors books genders prefectures/], 'tables';
    is_deeply $loader->table_columns('books'), [qw/id author_id name/], 'table_columns';

    is $loader->table_pk('authors'), 'id', 'authors pk';
    is $loader->table_pk('books'), 'id', 'books pk';
    is $loader->table_pk('genders'), 'name', 'genders pk';
    is $loader->table_pk('prefectures'), 'name', 'prefectures pk';

    $dbh->do($_) for (
        qq{
            CREATE TABLE composite (
                id   int,
                name varchar(255),
                primary key (id, name)
            )
        },
        qq{
            CREATE TABLE no_pk (
                code int,
                name varchar(255)
            )
        }
    );

    throws_ok { $loader->table_pk('composite') }
        qr/^DBIx::Skinny is not support composite primary key/,
        'caught exception for sonposite pk';
    throws_ok { $loader->table_pk('no_pk') }
        qr/^Could not find primary key/,
        'caught exception pk not found';

    $dbh->do($_) for (
        q{ DROP TABLE composite },
        q{ DROP TABLE no_pk },
    );
}
