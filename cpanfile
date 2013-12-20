requires 'perl', '5.008001';

on 'build' => sub {
    requires 'Class::Accessor::Fast';
    requires 'WWW::Mechanize';
    requires 'Perl6::Slurp';
    requires 'Web::Scraper';
    requires 'JSON::XS';
    requires 'YAML::XS';
    requires 'String::CamelCase';
    requires 'IO::Socket::SSL';
    requires 'LWP::Protocol::https';
    requires 'File::Path';
    requires 'Data::Section::Simple';
};

on 'test' => sub {
    requires 'Test::More', '0.98';
};
