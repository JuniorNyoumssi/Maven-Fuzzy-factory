SELECT * FROM mavenfuzzyfactory.website_sessions;

-- TASK : Identify where the bulk of the website sessions are coming from before 2012-04-12
-- Breaking it down by UTM source,campaign, and referring domain

USE mavenfuzzyfactory;

ALTER TABLE website_sessions
ADD created_date DATE;

ALTER TABLE website_sessions
ADD created_time  TIME;

UPDATE website_sessions
SET created_date =  DATE(created_at) ;

UPDATE website_sessions
SET created_time =  TIME(created_at) ;

SELECT utm_source,utm_campaign,http_referer,Count(website_session_id) as sessions
FROM website_sessions
WHERE created_date < '2012-04-12'
Group by utm_source, utm_campaign ,http_referer ;

-- TASK : Calculate the coversion rate (CVR) from session to order from the major traffic source
SELECT COUNT(DISTINCT(website_sessions.website_session_id)) as sessions,
       COUNT(DISTINCT(orders.order_id)) as orders,
       COUNT(orders.order_id)/ COUNT(website_sessions.website_session_id) as
       session_to_order_conv_rate
FROM website_sessions
LEFT JOIN orders on website_sessions.website_session_id = orders.website_session_id
where website_sessions.created_at < '2012-04-14' 
      AND website_sessions.utm_source = 'gsearch'
      AND website_sessions.utm_campaign  = 'nonbrand';

-- TASK: Pulling gsearch nonbrand trended session volume,by week
SELECT MIN(DATE(created_at)) as week_start_date ,COUNT(DISTINCT website_session_id) as sessions
FROM website_sessions
WHERE utm_source = 'gsearch' AND utm_campaign = 'nonbrand' AND created_at < '2012-05-12'
GROUP BY YEAR(created_at), WEEK(created_at) ;


-- TASK: Pull conversion rates from session to order by device type
SELECT website_sessions.device_type,COUNT(website_sessions.website_session_id) AS sessions
,COUNT(orders.order_id) AS orders,COUNT(orders.order_id)/COUNT(website_sessions.website_session_id) AS
session_to_order_conv_rate
FROM website_sessions
LEFT JOIN orders ON orders.website_session_id = website_sessions.website_session_id 
WHERE created_date < '2012-05-11' AND utm_source = 'gsearch' AND utm_campaign = 'nonbrand'
GROUP BY website_sessions.device_type ;

-- TASK : Find the total number of sessions by device type for each week start
SELECT  MIN(DATE(created_at)) AS week_start_date,
COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN website_sessions.website_session_id ELSE NULL END ) AS dtop_sessions,
COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_sessions.website_session_id ELSE NULL END ) AS mob_sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-04-15' AND '2012-06-09' AND utm_source = 'gsearch' AND utm_campaign = 'nonbrand'
GROUP BY WEEK(created_at) ;

-- TASK: Find Top Website Pages 
SELECT pageview_url,COUNT(DISTINCT website_pageview_id) as session_volume
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY pageview_url  ORDER BY session_volume DESC;

-- TASK : Find Top Entry Pages
CREATE TEMPORARY TABLE First_landing_page
SELECT MIN(website_pageview_id) AS min_pageview_id , website_session_id
FROM website_pageviews
WHERE created_at < '2012-06-12'
GROUP BY website_session_id; 

SELECT  website_pageviews.pageview_url,COUNT(First_landing_page.min_pageview_id)
FROM First_landing_page
LEFT JOIN website_pageviews ON First_landing_page.min_pageview_id = website_pageviews.website_pageview_id
GROUP BY website_pageviews.pageview_url;

DROP TABLE  viewcount_1;

-- TASK: Calculate Bounce Rates

CREATE TEMPORARY TABLE Min_pageview_id
SELECT MIN(website_pageview_id) AS view_id,website_session_id
FROM website_pageviews
WHERE created_at < '2012-06-14'
GROUP BY website_session_id;

CREATE TEMPORARY TABLE pageview_Landing
SELECT Min_pageview_id.website_session_id AS session_id, website_pageviews.pageview_url AS land_page
FROM Min_pageview_id
LEFT JOIN website_pageviews ON Min_pageview_id.view_id = website_pageviews.website_pageview_id;

CREATE TEMPORARY TABLE bounced_sessions
SELECT pageview_Landing.session_id as s_id,pageview_Landing.land_page AS land_page,COUNT(DISTINCT website_pageviews.website_pageview_id) AS pageview_count
FROM pageview_Landing
LEFT JOIN website_pageviews ON pageview_Landing.session_id=website_pageviews.website_session_id
GROUP BY pageview_Landing.session_id,pageview_Landing.land_page
HAVING COUNT(website_pageviews.website_pageview_id)= 1 ;

SELECT COUNT(DISTINCT bounced_sessions.s_id),COUNT(DISTINCT Min_pageview_id.website_session_id),
COUNT(DISTINCT bounced_sessions.s_id)/COUNT(DISTINCT Min_pageview_id.website_session_id) AS bounced_rate
FROM   Min_pageview_id
LEFT JOIN  bounced_sessions ON bounced_sessions.s_id= Min_pageview_id.website_session_id ;

-- TASK: Calculate Bounce Rates for two specific urls
    
CREATE TEMPORARY TABLE First_landingpage1
SELECT website_session_id, min(website_pageview_id) AS landing_id
FROM website_pageviews
WHERE created_at < '2012-06-28'
Group by website_session_id;

CREATE TEMPORARY TABLE Url_landingpage
SELECT 
       First_landingpage1.website_session_id, website_pageviews.pageview_url ,
       First_landingpage1.landing_id 
FROM First_landingpage1
LEFT JOIN website_pageviews ON First_Landingpage1.Landing_id = website_pageviews.website_pageview_id;

CREATE TEMPORARY TABLE Bounced_session
SELECT
	Url_landingpage.website_session_id,Url_landingpage.pageview_url,
    COUNT(DISTINCT website_pageviews.website_pageview_id) AS bounced_sessions
FROM  Url_landingpage
LEFT JOIN  website_pageviews ON Url_landingpage.website_session_id = website_pageviews.website_session_id
group by Url_landingpage.website_session_id,Url_landingpage.pageview_url
HAVING bounced_sessions = 1;


CREATE TEMPORARY TABLE Bounced_rates
SELECT 
    Url_landingpage.pageview_url,
    COUNT(DISTINCT Bounced_session.website_session_id)/COUNT(DISTINCT  Url_landingpage.website_session_id) AS bounced_rate
FROM  Url_landingpage
LEFT JOIN  Bounced_session ON  Url_landingpage.website_session_id = Bounced_session.website_session_id
GROUP BY Url_landingpage.pageview_url;


-- TASK : Carry out a Landing page trend analysis respecting certian criteria

CREATE TEMPORARY TABLE sessions_w_min_pv_id_and_view_count
SELECT 
     website_sessions.website_session_id,
     MIN(website_pageviews.website_pageview_id) AS first_pageview_id,
     COUNT(website_pageviews.website_pageview_id) AS count_pageviews
     
FROM  website_sessions
    LEFT JOIN  website_pageviews
        ON website_sessions.website_session_id = website_pageviews.website_session_id
        
WHERE website_sessions.created_at > '2012-06-01'
    AND website_sessions.created_at < '2012-08-31'
    AND website_sessions.utm_source = 'gsearch'
    AND website_sessions.utm_campaign = 'nonbrand'
    
GROUP BY 
     website_sessions.website_session_id;

CREATE TEMPORARY TABLE sessions_w_counts_lander_and_created_at
SELECT
     sessions_w_min_pv_id_and_view_count.website_session_id,
     sessions_w_min_pv_id_and_view_count.first_pageview_id,
     sessions_w_min_pv_id_and_view_count.count_pageviews,
     website_pageviews.pageview_url AS landing_page,
     website_pageviews.created_at AS session_created_at
     
FROM sessions_w_min_pv_id_and_view_count
    LEFT JOIN website_pageviews
        ON sessions_w_min_pv_id_and_view_count.first_pageview_id = website_pageviews.website_pageview_id;
        
SELECT 
   MIN(DATE(session_created_at)) AS week_start_date,
   COUNT(DISTINCT CASE WHEN count_pageviews = 1 THEN website_session_id ELSE NULL END) AS bounced_sessions,
   COUNT(DISTINCT CASE WHEN count_pageviews = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id),
   COUNT(DISTINCT CASE WHEN landing_page = '/home' THEN website_session_id ELSE NULL END) AS home_sessions,
   COUNT(DISTINCT CASE WHEN landing_page = 'lander-1' THEN website_session_id ELSE NULL END) AS lamder_sessions

FROM sessions_w_counts_lander_and_created_at

GROUP BY
    YEARWEEK(session_created_at);
    
 
-- TASK : Building Conversion Funnels    

SELECT 
	   website_sessions.website_session_id
      ,website_pageviews.pageview_url
	  ,CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS lander_1page
      ,CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS  home_page
      ,CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page
      ,CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page
      ,CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page
FROM website_sessions
LEFT JOIN website_pageviews
ON  website_pageviews.website_session_id = website_sessions.website_session_id
WHERE website_pageviews.created_at BETWEEN '2012-08-05' AND '2012-09-05'
AND utm_source = 'gsearch' AND utm_campaign='nonbrand';

CREATE TEMPORARY TABLE session_level_made_it
SELECT 
      website_session_id
	 ,MAX(lander_1page) AS lander_1page_made_it
     ,MAX(home_page) AS home_page_made_it
     ,MAX(products_page) AS products_page_made_it
     ,MAX(mrfuzzy_page) AS mrfuzzy_page_made_it
     ,MAX(cart_page) AS cart_page_made_it
FROM (SELECT 
	   website_sessions.website_session_id
      ,website_pageviews.pageview_url
	  ,CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS lander_1page
      ,CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS  home_page
      ,CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page
      ,CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page
      ,CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page
FROM website_sessions
LEFT JOIN website_pageviews
ON  website_pageviews.website_session_id = website_sessions.website_session_id
WHERE website_pageviews.created_at BETWEEN '2012-08-05' AND '2012-09-05'
AND utm_source = 'gsearch' AND utm_campaign='nonbrand'
) AS pageview_level

GROUP BY
      website_session_id ;
     
SELECT
	  COUNT(DISTINCT website_session_id) AS sessions
     ,COUNT(DISTINCT CASE WHEN lander_1page_made_it = 1 THEN website_session_id ELSE NULL END ) AS to_lander_1page
     ,COUNT(DISTINCT CASE WHEN home_page_made_it = 1 THEN website_session_id ELSE NULL END ) AS to_home
     ,COUNT(DISTINCT CASE WHEN products_page_made_it = 1 THEN website_session_id ELSE NULL END  ) AS to_products
     ,COUNT(DISTINCT CASE WHEN mrfuzzy_page_made_it = 1 THEN  website_session_id ELSE NULL END) AS to_mrfuzzy
     ,COUNT( DISTINCT CASE WHEN cart_page_made_it = 1 THEN website_session_id ELSE NULL END ) AS to_cart
FROM session_level_made_it;

SELECT
      COUNT(DISTINCT CASE WHEN lander_1page_made_it = 1 THEN website_session_id ELSE NULL END )/ COUNT(DISTINCT website_session_id) AS to_lander1_page
     ,COUNT(DISTINCT CASE WHEN home_page_made_it = 1 THEN website_session_id ELSE NULL END )/ COUNT(DISTINCT website_session_id) AS lander_clickrate
     ,COUNT(DISTINCT CASE WHEN products_page_made_it = 1 THEN website_session_id ELSE NULL END  )/ COUNT(DISTINCT website_session_id) AS home_clickrate
     ,COUNT(DISTINCT CASE WHEN mrfuzzy_page_made_it = 1 THEN  website_session_id ELSE NULL END)/ COUNT(DISTINCT website_session_id) AS products_clickrate
     ,COUNT( DISTINCT CASE WHEN cart_page_made_it = 1 THEN website_session_id ELSE NULL END )/ COUNT(DISTINCT website_session_id) AS mrfuzzy_clickrate
FROM session_level_made_it;
        
        






     





