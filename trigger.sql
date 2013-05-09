DELIMITER $$
CREATE TRIGGER redisgearman.redis_gearman AFTER INSERT ON redisgearman.user_page_views
  FOR EACH ROW BEGIN
    SET @ret=gman_do_background('redis_worker', json_object(NEW.user_id as `user_id`, NEW.timestamp as `timestamp`, NEW.page as `page`)); 
  END$$
DELIMITER ;
