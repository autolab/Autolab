#!/usr/bin/python

import praw
import os

USER_AGENT = 'Wallpaper Grabber'
SUBREDDIT = 'WQHD_Wallpaper'
FILE_TYPES = ['jpg', 'png']
DOWNLOAD_NAME = 'wall'

reddit = praw.Reddit(USER_AGENT)
submissions = reddit.get_subreddit(SUBREDDIT).get_top_from_day(limit=10)

for submission in submissions:
    picture_address = vars(submission)['url']
    picture_file_type = picture_address[-3:]

    print(picture_file_type)

    if picture_file_type in FILE_TYPES:
        os.system('wget ' + picture_address + ' -O '+ DOWNLOAD_NAME + '.' + picture_file_type)
        break
print('None Found')


