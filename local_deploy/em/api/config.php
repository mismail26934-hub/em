<?php
/**
 * Fleet EM Dashboard — server config.
 * Deploy folder `hosting/em/` to https://strakin.tech/em/
 */
return [
    'upload_secret' => 'fleet-em-change-me',
    'data_dir' => dirname(__DIR__) . '/data/list1',
    'public_base_path' => '/em/data/list1',
    'data_dir_list2' => dirname(__DIR__) . '/data/list2',
    'public_base_path_list2' => '/em/data/list2',
    'max_bytes' => 20 * 1024 * 1024,

    'db_host' => 'localhost',
    'db_name' => 'db_em',
    'db_user' => 'root',
    'db_pass' => '',
];
